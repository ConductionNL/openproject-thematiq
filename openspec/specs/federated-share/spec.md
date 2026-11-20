# Federated share of the setup

## Purpose

Two instances can keep the same setup without moving a file by hand: one serves its bundle to a request that carries a share key, the other pulls it and previews it like an uploaded configuration file. Both sides are off until an administrator turns them on, each on its own instance. The main code paths are `lib/open_project/thematiq/federation.rb`, `app/controllers/thematiq/share_controller.rb`, `app/controllers/thematiq/setup_endpoint_controller.rb`, `lib/open_project/thematiq/gallery/client.rb` and the share settings in `lib/open_project/thematiq/store.rb`.

## Requirements

### Requirement: Administrators only

The share settings page SHALL be open to administrators only; a holder of the "Manage the design" permission who is not an administrator SHALL NOT reach it.

#### Scenario: Brand manager

- **WHEN** a brand manager who is not an administrator opens `/admin/thematiq/share`
- **THEN** access is refused

### Requirement: Serving endpoint

`GET /thematiq/api/v1/setup` SHALL read no session and set no cookie, and SHALL answer 404 while serving is off or no key exists, 403 when the `X-Thematiq-Share-Key` header is missing or wrong, and 200 with the bundle as JSON when the key matches; every answer SHALL carry `Cache-Control: no-store` and `nosniff`.

#### Scenario: Serving off by default

- **WHEN** serving has never been turned on and a request asks for the setup
- **THEN** the answer is 404

#### Scenario: Right key

- **WHEN** serving is on and the request sends the stored share key
- **THEN** the answer is 200 with the same bundle the whole setup download gives

### Requirement: Share key

Turning serving on SHALL make a random share key when there is none, the key SHALL be compared in constant time, and making a new key SHALL stop the old key at once; the key SHALL never be part of the setup file.

#### Scenario: New key

- **WHEN** an administrator makes a new key
- **THEN** a request with the old key answers 403

### Requirement: Pull settings

Pulling SHALL be off by default, and saving the pull settings SHALL refuse an address that is not https or a key that is not a share key, and SHALL refuse turning pulling on without an address and a key.

#### Scenario: http address

- **WHEN** an administrator saves an `http://` address to pull from
- **THEN** nothing is stored and an error is shown

### Requirement: Pull with a preview

A pull SHALL read one https address with a 5 second timeout, without following redirects and up to the bundle size limit of 2 MB, SHALL check the file like an uploaded configuration file, and SHALL show what it changes on the same preview page; nothing SHALL change until the administrator confirms there.

#### Scenario: Other instance unreachable

- **WHEN** a pull cannot reach the other instance
- **THEN** the setup is unchanged and the error code is shown and recorded as the last pull status

#### Scenario: Pull off

- **WHEN** an administrator asks for a pull while pulling is off
- **THEN** no request is made and an error is shown
