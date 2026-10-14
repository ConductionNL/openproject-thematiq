# frozen_string_literal: true

# Command line tasks of the plugin, for scripted deployments and servers without a browser.
# Run them in OpenProject's directory, for example in the compose instance:
#   docker compose -f docker/compose.yml exec openproject bash -lc 'cd /app && bundle exec rake thematiq:status'
#
# A task that changes the setup leaves a row in the history, with "command line" as who. DRY_RUN=1 shows what an
# import or a restore would change and writes nothing.
namespace :thematiq do
  thematiq = OpenProject::Thematiq

  dry_run = -> { %w[1 true yes].include?(ENV["DRY_RUN"].to_s.downcase) }

  describe = lambda do |changes, names|
    return ["Nothing changes."] if changes.empty?

    name = ->(id) { id.nil? ? "the default design system" : (names[id] || id) }
    changes.map do |code, details|
      case code
      when "active" then "Design system in use: #{name.call(details[:from])} -> #{name.call(details[:to])}"
      when "custom_added", "custom_removed", "custom_changed" then "#{code.tr('_', ' ').capitalize}: #{details[:name]}"
      when "scope" then "Choice for #{details[:project] || 'the instance'} #{details[:module_name]}: #{details[:from] || 'inherit'} -> #{details[:to] || 'inherit'}"
      else code.tr("_", " ").capitalize
      end
    end
  end

  names_of = lambda do |store, checked|
    names = store.all_sets.to_h { |token_set| [token_set.id, token_set.name] }
    (checked&.settings&.dig("customs") || {}).each { |id, definition| names[id] ||= definition["name"].to_s }
    names
  end

  read_bundle = lambda do |store, text|
    thematiq::Bundle.read(text, catalogue: store.catalogue, project_exists: ->(identifier) { Project.exists?(identifier:) })
  end

  desc "Shows the design system in use and the counts of the plugin"
  task status: :environment do
    store = thematiq::Store.new
    active = store.active_token_set
    puts "Design system in use: #{active.name} (#{active.id})#{store.environment_id ? ', from THEMATIQ_DESIGN_SYSTEM' : ''}"
    puts "Custom design systems: #{store.custom_drafts.size} of #{thematiq::Store::MAX_CUSTOMS}"
    puts "Design systems in the catalogue: #{store.catalogue.sets.size}"
    puts "Projects may choose: #{store.projects_may_choose? ? 'yes' : 'no'}"
  end

  desc "Lists every design system: id and name"
  task list: :environment do
    thematiq::Store.new.all_sets.each { |token_set| puts "#{token_set.id}\t#{token_set.name}" }
  end

  desc "Makes a design system the one in use: rake thematiq:apply[zuiddrecht]"
  task :apply, [:id] => :environment do |_task, args|
    store = thematiq::Store.new
    abort "THEMATIQ_DESIGN_SYSTEM names the design system, so it cannot be changed here." if store.environment_id
    token_set = store.activate(args[:id].to_s)
    abort "No design system has the id #{args[:id].inspect}. rake thematiq:list shows them." unless token_set

    Thematiq::Change.record("command_line", user: nil, detail: "apply #{token_set.id}", store:)
    puts "In use now: #{token_set.name} (#{token_set.id})"
  end

  namespace :bundle do
    desc "Writes the whole setup as a configuration file: rake thematiq:bundle:export[setup.json], or to the screen without a file"
    task :export, [:file] => :environment do |_task, args|
      text = thematiq::Bundle.dump(Thematiq::Change.current_bundle)
      if args[:file].to_s.empty?
        puts text
      else
        File.write(args[:file], text)
        warn "Written: #{args[:file]}"
      end
    end

    desc "Reads a configuration file and makes it the setup: rake thematiq:bundle:import[setup.json]. DRY_RUN=1 changes nothing"
    task :import, [:file] => :environment do |_task, args|
      store = thematiq::Store.new
      abort "Name a file: rake thematiq:bundle:import[setup.json]" if args[:file].to_s.empty?
      abort "No file at #{args[:file]}" unless File.file?(args[:file])

      checked = begin
        read_bundle.call(store, File.read(args[:file], thematiq::Bundle::MAX_BYTES + 1))
      rescue thematiq::Bundle::Refused => e
        abort "Refused, nothing was changed: #{I18n.t("thematiq.bundle.errors.#{e.code}", default: e.code)}"
      end
      changes = thematiq::Bundle.changes(Thematiq::Change.current_bundle(store), checked)
      describe.call(changes, names_of.call(store, checked)).each { |line| puts "- #{line}" }
      next puts("Dry run: nothing was changed.") if dry_run.call

      Thematiq::Change.apply!(checked, store:)
      Thematiq::Change.record("command_line", user: nil, detail: "bundle import", store:)
      puts "The setup from #{args[:file]} is in use."
    end
  end

  desc "Lists the newest changes of the history"
  task history: :environment do
    abort "The history table is missing. Run the migrations." unless Thematiq::Change.ready?

    Thematiq::Change.order(id: :desc).limit(50).each do |change|
      puts [change.id, change.created_at.utc.iso8601, change.user_name || "-", change.action, change.detail, change.restorable? ? "restorable" : "-"].join("\t")
    end
  end

  desc "Restores a version of the history: rake thematiq:restore[42]. DRY_RUN=1 changes nothing"
  task :restore, [:id] => :environment do |_task, args|
    store = thematiq::Store.new
    change = Thematiq::Change.ready? ? Thematiq::Change.find_by(id: args[:id].to_i) : nil
    abort "No version has the id #{args[:id].inspect}. rake thematiq:history lists them." unless change
    abort "This version is too old: only who made the change and when are kept." unless change.restorable?

    checked = begin
      read_bundle.call(store, change.bundle_document)
    rescue thematiq::Bundle::Refused => e
      abort "Refused, nothing was changed: #{I18n.t("thematiq.bundle.errors.#{e.code}", default: e.code)}"
    end
    changes = thematiq::Bundle.changes(Thematiq::Change.current_bundle(store), checked)
    describe.call(changes, names_of.call(store, checked)).each { |line| puts "- #{line}" }
    next puts("Dry run: nothing was changed.") if dry_run.call

    Thematiq::Change.apply!(checked, store:)
    Thematiq::Change.record("restore", user: nil, detail: "##{change.id} on the command line", store:)
    puts "Version #{change.id} is restored."
  end

  desc "Prints the health report as JSON and exits 1 when something is degraded"
  task health: :environment do
    report = thematiq::Health.report(store: thematiq::Store.new,
                                     tables: { "uploads" => Thematiq::Upload.ready?, "scopes" => Thematiq::Scope.ready?,
                                               "changes" => Thematiq::Change.ready? },
                                     core_changed: thematiq::Shell::CoreGuard.changed_files)
    puts JSON.pretty_generate(report)
    exit(1) unless report["status"] == "ok"
  end
end
