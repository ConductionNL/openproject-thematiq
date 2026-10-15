# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The row of apps and modules in the top bar. The row itself is rendered in Shell::TopBar.
      # This holds the decisions that need no view: which entries, in which order, which is current.
      #
      # An entry has a key. A Nextcloud app has the key of Shell::NextcloudApps ("files", "mail").
      # An OpenProject module has the name of its item in core's top menu ("work_packages", "boards").
      module AppRow
        # The row of the design. The top bar follows the dossiq bar of Nextcloud, which has no row of tiles: the
        # logo, then the app switcher. An administrator can still set an own row.
        DEFAULT = [].freeze
        # The row of the earlier OpHeader design, offered as a start for an own row.
        OPHEADER = %w[files mail calendar work_packages boards gantt meetings].freeze
        MAX = 12
        OFF = "none"

        # The keys an administrator can pick on the admin page, in the order the field offers them:
        # Nextcloud's apps, then OpenProject's modules by the name of their item in core's top menu (17.9.1).
        # A key not listed here still works when the setting holds it. Core decides at render time who sees what.
        NEXTCLOUD_KEYS = %w[files mail calendar tasks talk contacts].freeze
        MODULE_KEYS = %w[home my_page my_time_tracking projects portfolios activity work_packages gantt team_planners boards
                         calendar_view meetings news cost_reports_global wikis].freeze
        KNOWN = (NEXTCLOUD_KEYS + MODULE_KEYS).freeze
        KEY = /\A[a-z0-9_-]{1,40}\z/

        # A project menu item whose global module has another name.
        ALIASES = { "team_planner_view" => "team_planners", "costs" => "cost_reports_global" }.freeze

        # Outline icons of the design for OpenProject's modules, 24 px grid. A module that is not
        # listed keeps the icon core gives it.
        ICONS = {
          "home" => "M3 10 12 3l9 7v10a1 1 0 0 1-1 1h-5v-7h-6v7H4a1 1 0 0 1-1-1z",
          "work_packages" => "M3 6h18M3 12h18M3 18h18",
          "gantt" => "M3 5h8M7 12h10M11 19h10M3 3v18",
          "boards" => "M4 5h16v14H4zM9 5v14M15 5v14",
          "meetings" => "M23 7l-7 5 7 5zM1 5h15v14H1z",
          "cost_reports_global" => "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20M12 6v6l4 2",
          "calendar_view" => "M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z",
          "wikis" => "M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"
        }.freeze

        # The stored setting as a list of keys: "files, mail, gantt". Nothing stored gives the
        # default row, "none" gives no row.
        def self.wanted(value)
          text = value.to_s.strip.downcase
          return [] if text == OFF
          return DEFAULT if text.empty?

          keys = text.split(/[\s,|]+/).grep(/\A[a-z0-9_-]{1,40}\z/).uniq.first(MAX)
          keys.empty? ? DEFAULT : keys
        end

        # The keys to show, in order.
        #
        #   wanted     the keys of the setting
        #   available  every key this user can open, in the order of the app switcher
        #   current    the key of the page the user is on, or nil
        #
        # A wanted key the user cannot open is left out, and the row is filled up from `available`
        # so it keeps its length. A current entry that is not in the row takes the last place.
        def self.pick(wanted, available, current = nil)
          return [] if wanted.empty?

          row = wanted & available
          row += (available - row).first(wanted.size - row.size)
          row[-1] = current if current && available.include?(current) && !row.include?(current) && row.any?
          row
        end

        # The key of the global module the page belongs to, from core's current menu item.
        def self.current_key(menu_item)
          name = menu_item.to_s
          ALIASES.fetch(name, name)
        end
      end
    end
  end
end
