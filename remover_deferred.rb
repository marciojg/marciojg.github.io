# frozen_string_literal: true

begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  # Activate the gem you are reporting the issue against.
  gem "activerecord", "6.0.0"
  # gem 'activerecord', '~> 6.0.0.rc2'
  gem "sqlite3"
  # gem 'sqlite3', '~> 1.4', '>= 1.4.1'
  gem "byebug"
end

require "active_record"
require "minitest/autorun"
require "logger"
require "byebug"

# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :physicians do |t|
    t.string :name
    t.timestamps
  end

  create_table :patients do |t|
    t.string :name
    t.timestamps
  end

  create_table :patients_physicians do |t|
    t.belongs_to :physician, index: true
    t.belongs_to :patient, index: true
    t.datetime :appointment_date
    t.timestamps
  end
end


class Physician < ActiveRecord::Base
  has_and_belongs_to_many :patients
  # validate  :patients_must_not_be_empty # Has the bell rung?

  # attr_accessor :patients_is_invalided # The bell

  # def patients_must_not_be_empty
  #   self.errors.add(:patients, :presence) if self.patients_is_invalided
  # end

  # def patients=(value)
  #   if value.all?(&:blank?)
  #     self.patients_is_invalided = true # Ring that bell!!!
  #   else
  #     self.patients_is_invalided = false # Ring that bell!!!
  #     super(value)
  #   end
  # end
end

class Patient < ActiveRecord::Base
  has_and_belongs_to_many :physicians
end

class BugTest < Minitest::Test
  def test_case
    physician = Physician.new(name: 'Jhon')
    patient1 = Patient.create!(name: 'Fulano1')
    patient2 = Patient.create!(name: 'Fulano2')

    physician.patients = [patient1, patient2]
    physician.save!

    assert_equal true, physician.valid?
    assert_equal 2, physician.patients.count

    byebug

    # physician.patients = []
    # assert_equal false, physician.valid?
    # assert_equal 2, physician.patients.count

    # physician.patients = ['']
    # assert_equal false, physician.valid?
    # assert_equal 2, physician.patients.count
  end
end
