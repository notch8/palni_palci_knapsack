# HykuKnapsack
Hyku Knapsack is a little wrapper around Hyku to make development and deployment easier. Primary goals of this project include making contributing back to the Hyku project easier and making upgrades a snap.

## Usage

Start by making a clone.  You can do this by:

- (Preferred) Creating a [New Repository](#new-repository) and pushing your local clone 
- Creating a [Fork on Github](#fork-on-github)

### New Repository

In your Repository host of choice, create a new (and for now empty) repository.  That will provide you `$NEW_REPO_URL`.  

**Note:** Due to bundler limitations, the name of your project (e.g. `$PROJECT_NAME`) must only contain letters, numbers and underscores.

```bash
git clone git@github.com:samvera-labs/hyku_knapsack.git $PROJECT_NAME_knapsack
cd $PROJECT_NAME_knapsack
git remote rename origin upstream
git remote add origin $NEW_REPO_URL
git branch -M main
git push -u origin main
```

### Fork on Github

If you choose to fork Knapsack, be aware that this will impact how you manage pull requests via Github.  Namely as you submit PRs on your Fork, the UI might default to applying that to the fork's origin (e.g. Knapsack upstream).

### Overrides
Before overriding anything, please think hard about whether what you are working on is a bug or feature that can apply to Hyku itself. If it is, please make a branch in your Hyku checkout (`./hyrax-webapp`) and do the work there. [See here](https://github.com/samvera-labs/hyku_knapsack/wiki/Hyku-Branches) for more information about working with Hyku branches in your Knapsack

Adding decorators to override features is fairly simple. We do recommend some best practices [found here](https://github.com/samvera-labs/hyku_knapsack/wiki/Decorators-and-Overrides)

Any file with `_decorator.rb` in the app or lib directory will automatically be loaded along with any classes in the app directory.

### Deployment scripts

Deployment code can be added as needed.

### Theme files

Theme files (views, css, etc) can be added in the the Knapsack. We recommend adding an override comment as [described here](https://github.com/samvera-labs/hyku_knapsack/wiki/Decorators-and-Overrides)

### Gems

It can be useful to add additional gems to the bundle. This can be done w/o editing Hyku by adding them as dependencies to `hyku_knapsack.gemspec`

## Installation
If not using a current version, add this line to Hyku's Gemfile:

```ruby
gem "hyku_knapsack", github: 'samvera-labs/hyku_knapsack', branch: 'main'
```

And then execute:
```bash
$ bundle
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
