# frozen_string_literal: true

# OVERRIDE Hyku 7.1.0 (samvera/hyku#3313) to read the non-EDTF dates PALNI/PALCI tenants hold.
# Upstream only spans `/` intervals and reads a year at the start of a value, so `1890-1910`
# indexes as 1890 alone, `1860, 1861, 1862` as 1860 alone, and `ca. 1967` as nothing.
module Hyku
  module DateRangeYearsDecorator
    HYPHEN_RANGE = /\A\s*(\d{4})\s*[-–—]\s*(\d{4})\s*\z/
    LIST_SEPARATOR = /\s*[,;]\s*/
    APPROXIMATE_PREFIX = /\A\s*(?:ca\.?|circa|c\.)\s*/i

    def years_in(value)
      text = value.to_s.sub(APPROXIMATE_PREFIX, '')
      return text.split(LIST_SEPARATOR).flat_map { |part| years_in(part) } if text.match?(LIST_SEPARATOR)

      super(text.sub(HYPHEN_RANGE, '\\1/\\2'))
    end
  end
end

Hyku::DateRangeYears.singleton_class.prepend(Hyku::DateRangeYearsDecorator)
