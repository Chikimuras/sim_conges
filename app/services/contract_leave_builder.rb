# frozen_string_literal: true

require "date"
require "bigdecimal"
require "bigdecimal/util"
require_relative "leave_period"

# ContractLeaveBuilder splits a contract (start_date, end_date, monthly_salary)
# into sequential leave-accrual periods. Each period is an instance of LeavePeriod.
#
# Rules:
# • A standard period runs from June 1 of year N to May 31 of year N+1.
# • The first period starts on the contract's start_date and ends on May 31 of that same year
#   if start_date is before June 1, or May 31 of the next year if start_date is on/after June 1.
# • The last period ends at contract's end_date if that is before its natural May 31.
class ContractLeaveBuilder
  attr_reader :contract_start, :contract_end, :monthly_salary

  # @param contract_start [Date] date the contract begins (inclusive)
  # @param contract_end   [Date] date the contract ends (inclusive)
  # @param monthly_salary [BigDecimal, Numeric, String] fixed gross salary per month
  def initialize(contract_start:, contract_end:, monthly_salary:)
    @contract_start = contract_start
    @contract_end   = contract_end
    @monthly_salary = monthly_salary.to_d
  end

  # Returns an Array<LeavePeriod> in chronological order, covering the full contract.
  def build_periods
    periods = []

    # Determine the first period's start_date (just the contract_start)
    first_start = contract_start

    # Determine the first period's natural end_date:
    #   If first_start.month >= 6, end at May 31 of first_start.year + 1
    #   Else, end at May 31 of first_start.year
    if first_start.month >= 6
      natural_first_end = Date.new(first_start.year + 1, 5, 31)
    else
      natural_first_end = Date.new(first_start.year, 5, 31)
    end

    # If the contract ends before that natural May 31, truncate it
    first_end = contract_end < natural_first_end ? contract_end : natural_first_end

    # Add the first LeavePeriod
    periods << LeavePeriod.new(
      start_date:     first_start,
      end_date:       first_end,
      monthly_salary: monthly_salary
    )

    # If the contract continues past first_end, create subsequent full or truncated periods
    current_end = first_end

    while current_end < contract_end
      # Next period always starts on June 1 of the year of the last period's end
      next_start = Date.new(current_end.year, 6, 1)
      # If next_start is before the contract_start (edge case), honor contract_start
      next_start = contract_start if next_start < contract_start

      # Natural end of this next period is May 31 of next_start.year + 1
      natural_end = Date.new(next_start.year + 1, 5, 31)
      actual_end = contract_end < natural_end ? contract_end : natural_end

      periods << LeavePeriod.new(
        start_date:     next_start,
        end_date:       actual_end,
        monthly_salary: monthly_salary
      )

      current_end = actual_end
    end

    periods
  end
end
