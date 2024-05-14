# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'spec_system_helper'
require 'pp'


module GcovTestCases

  def _add_gcov_section_in_project(project_file_path, name, values)
    project_file_contents = File.readlines(project_file_path)
    name_index = project_file_contents.index(":gcov:\n")

    if name_index.nil?
      # Something wrong with project.yml file, no project section?
      return
    end

    project_file_contents.insert(name_index + 1, "  :#{name}:\n")
    values.each.with_index(2) do |value, index|
      project_file_contents.insert(name_index + index, "    - #{value}\n")
    end

    File.open(project_file_path, "w+") do |f|
      f.puts(project_file_contents)
    end
  end
  
  def _add_gcov_option_in_project(project_file_path, option, value)
    project_file_contents = File.readlines(project_file_path)
    option_index = project_file_contents.index(":gcov:\n")

    if option_index.nil?
      # Something wrong with project.yml file, no project section?
      return
    end

    project_file_contents.insert(option_index + 1, "  :#{option}: #{value}\n")
  
    File.open(project_file_path, "w+") do |f|
      f.puts(project_file_contents)
    end
  end

  def add_gcov_section(name, values)
    _add_gcov_section_in_project("project.yml", name, values)
  end

  def add_gcov_option(option, value)
    _add_gcov_option_in_project("project.yml", option, value)
  end

  def can_test_projects_with_gcov_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_fail
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_fail_because_of_uncovered_files
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        add_gcov_option("abort_on_uncovered", "TRUE")
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("uncovered_example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(0) #TODO: IS THIS DESIRED?(255) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_success_because_of_ignore_uncovered_list
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        add_gcov_option("abort_on_uncovered", "TRUE")
        add_gcov_section("uncovered_ignore_list", ["src/foo_file.c"])
        FileUtils.cp test_asset_path("example_file.h"), "src/"
        FileUtils.cp test_asset_path("example_file.c"), "src/"
        FileUtils.cp test_asset_path("uncovered_example_file.c"), "src/foo_file.c" # "src/foo_file.c" is in the ignore uncovered list
        FileUtils.cp test_asset_path("test_example_file_success.c"), "test/"

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_success_because_of_ignore_uncovered_list_with_globs
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        add_gcov_option("abort_on_uncovered", "TRUE")
        add_gcov_section("uncovered_ignore_list", ["src/B/**"])
        FileUtils.mkdir_p(["src/A", "src/B/C"])
        FileUtils.cp test_asset_path("example_file.h"), "src/A"
        FileUtils.cp test_asset_path("example_file.c"), "src/A"
        FileUtils.cp test_asset_path("uncovered_example_file.c"), "src/B/C/foo_file.c" # "src/B/**" is in the ignore uncovered list
        FileUtils.cp test_asset_path("test_example_file_success.c"), "test/"

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end


  def can_test_projects_with_gcov_with_compile_error
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_boom.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(1) # Since a test explodes, we return error here
        expect(output).to match(/(?:ERROR: Ceedling Failed)|(?:Ceedling could not complete operations because of errors)/)
      end
    end
  end

  def can_fetch_project_help_for_gcov
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        output = `bundle exec ruby -S ceedling help`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/ceedling gcov:\*/i)
        expect(output).to match(/ceedling gcov:all/i)
      end
    end
  end

  def can_create_html_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all`
        expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr'\.\.\./)
        expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator'\.\.\./)
        expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
      end
    end
  end

  def can_create_gcov_html_report_from_crashing_test_runner_with_enabled_debug_and_cmd_args_set_to_true_for_test_cases_not_causing_crash
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), 'project.yml'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => true },
                                       :test_runner => { :cmdline_args => true }})

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/gcov/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/gcov/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
        expect(output).to match(/example_file.c \| Lines executed:5?0.00% of 4/)
        expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr'\.\.\./)
        expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator'\.\.\./)
        expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
      end
    end
  end

  def can_create_gcov_html_report_from_crashing_test_runner_with_enabled_debug_and_cmd_args_set_to_true_with_zero_coverage
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), 'project.yml'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => true },
                                       :test_runner => { :cmdline_args => true }})

        output = `bundle exec ruby -S ceedling gcov:all --exclude_test_case=test_add_numbers_adds_numbers 2>&1`
        expect($?.exitstatus).to match(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/gcov/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/gcov/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+1/)
        expect(output).to match(/IGNORED:\s+0/)
        expect(output).to match(/example_file.c \| Lines executed:0.00% of 4/)

        expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr'\.\.\./)
        expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator'\.\.\./)
        expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
      end
    end
  end

  def can_create_gcov_html_report_from_test_runner_with_enabled_debug_and_cmd_args_set_to_true_with_100_coverage_when_excluding_crashing_test_case
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), 'project.yml'

        @c.merge_project_yml_for_test({:test_runner => { :cmdline_args => true }})

        add_test_case = "\nvoid test_difference_between_two_numbers(void)\n"\
                        "{\n" \
                        "  TEST_ASSERT_EQUAL_INT(0, difference_between_numbers(1,1));\n" \
                        "}\n"
        
        updated_test_file = File.read('test/test_example_file_crash.c').split("\n")
        updated_test_file.insert(updated_test_file.length(), add_test_case)
        File.write('test/test_example_file_crash.c', updated_test_file.join("\n"), mode: 'w')

        output = `bundle exec ruby -S ceedling gcov:all --exclude_test_case=test_add_numbers_will_fail 2>&1`
        expect($?.exitstatus).to match(0)
        expect(File.exist?('./build/gcov/results/test_example_file_crash.pass'))
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+2/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
        expect(output).to match(/example_file.c \| Lines executed:100.00% of 4/)

        expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr'\.\.\./)
        expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator'\.\.\./)
        expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
      end
    end
  end
end
