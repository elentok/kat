require 'minitest/autorun'
require File.dirname(__FILE__) + '/../../lib/kat/options'

describe Kat::Options do

  describe 'options map' do
    let(:opts) { Kat::Options.options_map }

    it 'is a hash' do
      opts.must_be_instance_of Hash
      opts.keys.wont_be_empty
      opts.values.wont_be_empty
    end

    it 'has symbolised keys' do
      opts.keys.each { |key|
        key.must_be_instance_of Symbol
        key.wont_equal :size
      }
    end

    it 'has a hash for values, each with a description' do
      opts.values.each { |value|
        value.must_be_instance_of Hash
        value.keys.must_include :desc
      }
    end

    it 'has symbolised keys in each value' do
      opts.each { |key, value|
        value.each { |k, v|
          k.must_be_instance_of Symbol
          case k
          when :desc
            v.must_be_instance_of String
          when :multi
            v.must_equal true
          when :short
            v.must_be_instance_of Symbol
            v.must_match /\A([a-z]|none)\Z/
          else
            v.must_be_instance_of Symbol
          end
        }
      }
    end
  end

  describe 'parse options' do
    it 'returns an options hash with everything off' do
      args = ['foobar']
      opts = Kat::Options.parse args

      args.must_equal ['foobar']

      opts.must_be_instance_of Hash
      opts.wont_be_empty
      opts.values.each { |value|
        [[], nil, false].must_include value
      }
    end

    it 'returns an options hash with some options switched on' do
      args = %w(foobar --or baz --colour -t age)
      opts = Kat::Options.parse args

      args.must_equal ['foobar']

      opts[:or].must_equal %w(baz)
      opts[:sort].must_equal 'age'
      %i(colour colour_given or_given sort_given).each { |key|
        opts[key].must_equal true
      }
    end
  end

end
