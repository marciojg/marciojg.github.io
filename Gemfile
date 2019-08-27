source "https://rubygems.org"

# gem "minima", "~> 2.5"
gem "plainwhite"

# gem "jekyll", "~> 4.0.0" Para usar local, descomenta esse e comenta o de baixo
gem "github-pages", group: :jekyll_plugins

install_if -> { RUBY_PLATFORM =~ %r!mingw|mswin|java! } do
  gem "tzinfo", "~> 1.2"
  gem "tzinfo-data"
end

gem "wdm", "~> 0.1.1", :install_if => Gem.win_platform?
