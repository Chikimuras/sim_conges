# Leave Simulator (Rails 8)

This Rails application is a “mini-simulator” for calculating paid leave (“congés payés”) for a part‐year (“année incomplète”) childcare contract. It implements the rules of the French assistants maternels collective agreement (CCN) for accrual and payment of leave in three different modes.

---

## Table of Contents

1. [Requirements](#requirements)
2. [Dependencies & Versions](#dependencies--versions)
3. [Installation & Setup](#installation--setup)
    1. [Clone Repository](#1-clone-repository)
    2. [Install Ruby & Rails](#2-install-ruby--rails)
    3. [Bundle Install & Importmap](#3-bundle-install--importmap)
    4. [Hotwire (Turbo + Stimulus) Setup](#4-hotwire-turbo--stimulus-setup)
    5. [Tailwind CSS Setup](#5-tailwind-css-setup)
    6. [Database Setup](#6-database-setup)
    7. [Routing & Initial Verification](#7-routing--initial-verification)
4. [Usage](#usage)
5. [Project Structure](#project-structure)
6. [How to Contribute](#how-to-contribute)

---

## Requirements

- **Ruby**     3.3.7
- **Rails**          8.0.2
- **SQLite3** (default development database)
- No Node/Yarn requirement (uses Importmap instead)
- **Git** (for version control)

---

## Dependencies & Versions

In `Gemfile`:

```ruby
ruby "3.3.7"

gem "rails", "8.0.2"
gem "sqlite3", "~> 1.4"

# JavaScript layering (Importmap instead of Node)
gem "importmap-rails", "~> 1.3"
gem "hotwire-rails", "~> 1.2"       # Includes turbo-rails + stimulus-rails

# Tailwind CSS integration (v4 via tailwindcss-rails)
gem "tailwindcss-rails", "~> 2.0"

# (Optional) For UI components via Tailwind
# Will be configured in tailwind.config.js:
#   plugin 'daisyui'
```

After running `bundle install`, you should see versions similar to:

```
importmap-rails (1.3.x)
hotwire-rails    (1.2.x)
turbo-rails      (1.3.x)
stimulus-rails   (1.2.x)
tailwindcss-rails (2.0.x)
```

---

## Installation & Setup

Follow these steps **in order** to initialize and run the project locally.

### 1. Clone Repository

```bash
# Replace <your-git-url> with the actual URL you or your team provided
git clone <your-git-url> leave_simulator
cd leave_simulator
```

### 2. Install Ruby & Rails

> Ensure you’re using **Ruby 3.3.7**. If you use a version manager (rbenv, rvm, asdf), switch accordingly:

```bash
rbenv install 3.3.7      # if not already installed
rbenv local 3.3.7        # set project Ruby version
ruby -v                  # should show “ruby 3.3.7”
```

If you don’t have Rails 8.0.2 installed globally, run:

```bash
gem install rails -v 8.0.2
rails -v                # should show “Rails 8.0.2”
```

### 3. Bundle Install & Importmap

1. Install all Ruby gems:

   ```bash
   bundle install
   ```

2. Run Importmap installer (creates `config/importmap.rb`, sets up `app/assets/javascripts/application.js`):

   ```bash
   rails importmap:install
   ```

    - This will generate:
        - `config/importmap.rb`
        - `app/assets/javascripts/application.js`
        - Necessary boilerplate for managing JS via Importmap.

### 4. Hotwire (Turbo + Stimulus) Setup

With Importmap in place, install Hotwire:

```bash
rails hotwire:install
```

- This will:
    - Add/import `turbo-rails` and `stimulus-rails` via Importmap.
    - Generate `app/javascript/controllers/` folder with `index.js` and example controllers.
    - Inject `<%= javascript_importmap_tags %>` into your `layouts/application.html.erb` (if not already present).

#### Verify in `application.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>LeaveSimulator</title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <!-- Tailwind CSS will be loaded here later -->
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>

    <!-- Importmap JS (Turbo + Stimulus) -->
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-base-200 text-base-content">
    <%= yield %>
  </body>
</html>
```

- Confirm `<%= javascript_importmap_tags %>` is in `<head>`.

### 5. Tailwind CSS Setup

Use the `tailwindcss-rails` gem to install Tailwind v4:

```bash
bundle install               # ensure gem is available
rails tailwindcss:install
```

This generates:

- `app/assets/builds/application.css` (compiled Tailwind CSS).
- `app/assets/builds/application.css.gz` (precompressed).
- Adjusted `application.html.erb` to load `application.css`.


#### Verify CSS path in layout

The generator typically updates `application.html.erb` to load Tailwind from `app/assets/builds/application.css`. Make sure you see:

```erb
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
```

Rails will look for `app/assets/builds/application.css`.

### 6. Database Setup

By default, this app uses SQLite3 in development. To set up the database:

```bash
rails db:create
rails db:migrate
```

- If you ever add new migrations, run `rails db:migrate` again.

### 7. Routing & Initial Verification

1. **Configure routes** in `config/routes.rb`:

   ```ruby
   Rails.application.routes.draw do
     # Root path displays the form
     root "simulator#index"

     # POST "/simulate" triggers SimulatorController#simulate
     post "/simulate", to: "simulator#simulate"
   end
   ```

2. **Verify server startup**:

   ```bash
   rails server
   ```
    - Visit `http://localhost:3000/` in your browser.
    - You should see the “Simulateur de congés payés” form.
    - Submitting the form (using dummy dates) should not break; if you see errors, check logs.

3. **Controllers & Views**
    - `app/controllers/simulator_controller.rb` handles two actions:
        - `index`: renders the form.
        - `simulate`: parses parameters, validates, uses `ContractMonthlyCalculator`, and renders results into a `<turbo-frame>`.
    - `app/views/simulator/index.html.erb` contains the form wrapped in a `<turbo-frame id="form_frame">`, plus an empty `<turbo-frame id="results_frame">`.
    - `app/views/simulator/simulate.html.erb` contains only the results portion, wrapped in `<turbo-frame id="results_frame">…</turbo-frame>`.

---

## Usage

1. **Start the server**:
   ```bash
   rails server
   ```
2. **Open** `http://localhost:3000/` in your browser.
3. **Fill in the form**:
    - Date de début de contrat (any valid date, e.g. `2023-09-11`)
    - Date de fin de contrat (must be after start, e.g. `2025-07-25`)
    - Salaire brut mensuel (€) (between 200 and 1200, e.g. `1000`)
4. **Click** “Calculer la simulation.”
    - The form posts via Turbo to `simulate`, which returns HTML in the `results_frame`.
    - You’ll see two DaisyUI/Tailwind‐styled cards:
        1. **Leave Periods** (period start/end, months worked, days acquired, valuation by salary and 10%, chosen max)
        2. **Monthly Breakdown** (for each month: salary due, leave Integral, leave 1/12, leave 10% monthly, leave 10% regularization, leave 10% total)
5. **Switch theme** (light/dark) by toggling the `<html data-theme="dark">` attribute or using a DaisyUI theme switcher (if you added one).

---

## Project Structure

```
leave_simulator/
├── Gemfile
├── Gemfile.lock
├── Rakefile
├── config/
│   ├── application.rb
│   ├── boot.rb
│   ├── database.yml
│   ├── importmap.rb
│   ├── routes.rb
│   └── …
├── app/
│   ├── assets/
│   │   └── builds/
│   │       └── application.css          # Tailwind‐compiled CSS
│   ├── controllers/
│   │   └── simulator_controller.rb
│   ├── services/
│   │   ├── leave_period.rb
│   │   ├── contract_leave_builder.rb
│   │   └── contract_monthly_calculator.rb
│   ├── views/
│   │   └── simulator/
│   │       ├── index.html.erb            # Form wrapped in form_frame & results_frame
│   │       └── simulate.html.erb         # Results wrapped in results_frame
│   └── …
└── …
```

---

## How to Contribute

1. **Fork** this repository.
2. **Create** a new feature branch:
   ```bash
   git checkout -b feature/awesome-new-feature
   ```
3. **Implement** your changes (unit tests and/or manual tests).
4. **Commit** with descriptive messages:
   ```bash
   git add .
   git commit -m "Feature: add X functionality to Y"
   ```
5. **Push** to your fork:
   ```bash
   git push origin feature/awesome-new-feature
   ```
6. **Open a Pull Request** against the `main` branch.
7. **Reviewers** will test and merge if approved.

---

Thank you for using **Leave Simulator**! If you encounter any issues, please open an issue or submit a pull request.
