# frozen_string_literal: true

require_relative '../spec_helper'
require './lib/search-and-replace'

require 'fileutils'
require 'mixlib/shellout'
require 'tempfile'
require 'yaml'

describe SearchAndReplace do
  let(:files) { %W[#{__dir__}/fixtures/bad_content.txt #{__dir__}/fixtures/good_content.txt] }

  context 'when loading a config' do
    let(:configs) do
      yaml = YAML.safe_load(IO.read("#{__dir__}/fixtures/search-and-replace.yaml"))
      # Convenience naming the different configs
      {
        'foobar' => yaml[0],
        'bad regexp' => yaml[1],
        'insensitive' => yaml[2],
        'regex foobar' => yaml[3]
      }
    end

    let(:sar) do
      lambda do |c|
        described_class.from_config(files, c)
      end
    end

    it 'contains all foobar config entries' do
      expect(sar.call(configs['foobar']).search).to be_a(String)
      expect(sar.call(configs['foobar']).search).to eq('foobar')
      expect(sar.call(configs['foobar']).replacement).to eq('fooBAZ')
    end

    it 'contains all bad regexp config entries' do
      expect(sar.call(configs['bad regexp']).search).to be_a(Regexp)
      expect(sar.call(configs['bad regexp']).search).to eq(/Bad\s*Regexp/)
      expect(sar.call(configs['bad regexp']).search.options).to eq(0)
      expect(sar.call(configs['bad regexp']).replacement).to be_nil
    end

    it 'contains all insensitive config entries' do
      expect(sar.call(configs['insensitive']).search).to be_a(Regexp)
      expect(sar.call(configs['insensitive']).search).to eq(/InsensitiveREGEXP/i)
      expect(sar.call(configs['insensitive']).search.options).to eq(Regexp::IGNORECASE)
      expect(sar.call(configs['insensitive']).replacement).to be_nil
    end

    it 'has correct number of occurrences for foobar config' do
      expect(sar.call(configs['foobar']).parse_files[0]).to be_a(SearchAndReplace::FileMatches)
      expect(sar.call(configs['foobar']).parse_files[0].length).to eq(1)
      expect(sar.call(configs['foobar']).parse_files[1]).to be_a(SearchAndReplace::FileMatches)
      expect(sar.call(configs['foobar']).parse_files[1].empty?).to be true
    end

    it 'has correct number of occurrences for bad regexp config' do
      expect(sar.call(configs['bad regexp']).parse_files[0]).to be_a(SearchAndReplace::FileMatches)
      expect(sar.call(configs['bad regexp']).parse_files[0].length).to eq(2)
      expect(sar.call(configs['bad regexp']).parse_files[1]).to be_a(SearchAndReplace::FileMatches)
      expect(sar.call(configs['bad regexp']).parse_files[1].empty?).to be true
    end

    it 'has correct number of occurrences for foobar config' do
      expect(sar.call(configs['insensitive']).parse_files[0]).to be_a(SearchAndReplace::FileMatches)
      expect(sar.call(configs['insensitive']).parse_files[0].length).to eq(1)
      expect(sar.call(configs['insensitive']).parse_files[1]).to be_a(SearchAndReplace::FileMatches)
      expect(sar.call(configs['insensitive']).parse_files[1].empty?).to be true
    end

    it 'does not register an occurrence if replacement would not change line' do
      expect(sar.call(configs['regex foobar']).parse_files[0]).to be_a(SearchAndReplace::FileMatches)
      expect(sar.call(configs['regex foobar']).parse_files[0].length).to eq(0)
    end

    it 'prints an occurrence correctly' do
      expect(sar.call(configs['foobar']).parse_files[0].first.to_s).to eq \
        "#{__dir__}/fixtures/bad_content.txt, line 4, col 13:\n" \
        "    Here's one: foobar\n" \
        '                ^'
    end
  end

  context 'when run from the command-line' do
    let(:sar) do
      cmd = "#{__dir__}/../../bin/search-and-replace.rb #{args} #{run_files.map(&:path).join(' ')}"
      Mixlib::ShellOut.new(cmd).run_command
    end
    let(:bad_file) { files[0] }
    let(:good_file) { files[1] }
    let(:bad_tempfile) { Tempfile.new('rspec-sar') }
    let(:good_tempfile) { Tempfile.new('rspec-sar') }

    before do
      FileUtils.cp(bad_file, bad_tempfile.path)
      FileUtils.cp(good_file, good_tempfile.path)
    end

    context 'with a good file' do
      let(:run_files) { [good_tempfile] }
      let(:args) { '-s Something' }

      it 'exits normally' do
        expect(sar.exitstatus).to eq(0)
      end
    end

    context 'with a bad file' do
      let(:run_files) { [bad_tempfile] }
      let(:args) { '-s foobar' }

      it 'exits with error' do
        expect(sar.exitstatus).to eq(1)
      end
    end

    context 'with a bad file and replacement' do
      let(:run_files) { [bad_tempfile] }
      let(:args) { '-s foobar -r youbar' }

      it 'exits with error' do
        expect(sar.exitstatus).to eq(1)
      end

      it 'replaces string with replacement' do
        expect(sar.exitstatus).to eq(1)
        new_content = IO.read(run_files[0].path)
        expect(new_content.index('foobar')).to be_nil
        expect(new_content.index('youbar')).to be >= 0
      end
    end
  end
end
