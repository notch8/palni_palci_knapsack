# frozen_string_literal: true

require "rails_helper"

RSpec.describe Hyku::DateRangeYears do
  describe ".call" do
    {
      '1890-1910' => (1890..1910).to_a,
      '1890 - 1910' => (1890..1910).to_a,
      '1890–1910' => (1890..1910).to_a,
      '1860, 1861, 1864' => [1860, 1861, 1864],
      '1950-1952; 1960' => [1950, 1951, 1952, 1960],
      'ca. 1967' => [1967],
      'Circa 1956' => [1956],
      'c. 1900' => [1900],
      '2020-05-15' => [2020],
      '2020-05' => [2020],
      '1974' => [1974],
      '1791/1793' => [1791, 1792, 1793],
      "Early 1920's" => [],
      'Unknown' => []
    }.each do |value, years|
      it "reads #{value.inspect} as #{years.inspect}" do
        expect(described_class.call(value)).to eq(years)
      end
    end
  end
end
