# frozen_string_literal: true

require "date"
require "bigdecimal"
require "bigdecimal/util"
require_relative "contract_leave_builder"
require_relative "leave_period"

# ContractMonthlyCalculator builds a detailed breakdown for each calendar month
# of a contract (start_date, end_date, monthly_salary).
#
# For each month it calculates:
#   • salary_due       => prorated salary for that month (if partial or full)
#   • leave_integral   => amount of leave paid in "full June payment" mode
#   • leave_1_12       => amount of leave paid in "1/12 per month" mode
#   • leave_10pct      => amount of leave paid in "10% each month" mode
#
# It reuses ContractLeaveBuilder to create LeavePeriod instances.
class ContractMonthlyCalculator
  attr_reader :contract_start, :contract_end, :monthly_salary, :periods

  # @param contract_start [Date]    inclusive start date of contract
  # @param contract_end   [Date]    inclusive end date of contract
  # @param monthly_salary [BigDecimal, Numeric, String] gross salary per full month
  def initialize(contract_start:, contract_end:, monthly_salary:)
    @contract_start = contract_start
    @contract_end   = contract_end
    @monthly_salary = monthly_salary.to_d

    # Build all leave-accrual periods for the entire contract
    @periods = ContractLeaveBuilder.new(
      contract_start:   contract_start,
      contract_end:     contract_end,
      monthly_salary:   monthly_salary
    ).build_periods
  end

  # Returns an Array of Hashes. Each hash corresponds to one calendar month
  # covered by the contract, with keys:
  #   :month            => Date object at the first day of that month
  #   :salary_due       => BigDecimal for salary (prorated or full)
  #   :leave_integral   => BigDecimal for leave in "full June" mode
  #   :leave_1_12       => BigDecimal for leave in "1/12 per month" mode
  #   :leave_10pct      => BigDecimal for leave in "10% each month" mode
  #
  # IMPORTANT: all amounts are rounded to 2 decimals where appropriate.
  def calculate_monthly_details
    result = []

    # 1) Precompute total leave per period (value_due)
    period_totals = {}
    periods.each_with_index do |period, idx|
      period_totals[idx] = period.value_due
    end

    # 2) Build a hash that maps each month => leave amount (period_total/12) for "1/12" mode
    leave_1_12_schedule = {}
    period_totals.each do |idx, total_amount|
      period_end = periods[idx].end_date
      # First month of disbursement is the month immediately after period_end
      payment_start_month = Date.new(period_end.year, period_end.month, 1).next_month

      12.times do |i|
        month = payment_start_month >> i
        leave_1_12_schedule[month] = (total_amount.to_d / 12.to_d).round(2)
      end
    end

    # 3) Build a hash that maps each month => leave amount (total_amount) for "full June" mode
    #    We pay the entire period_total in June of the next calendar period.
    leave_integral_schedule = {}
    period_totals.each do |idx, total_amount|
      period_end = periods[idx].end_date
      # Full payment month is June in the year after period_end's year if period_end is before June?
      # Actually: If a period ends any time in May N, its June payment is June of that same N.
      # But because a period ALWAYS ends on or before May 31 (by builder logic),
      # the next month is always June. So:
      payment_month = Date.new(period_end.year, period_end.month, 1).next_month
      # Make sure this next_month is June; if contract ends in May or earlier, next_month is June.
      # If contract_end = May 31, next_month = June 1. Good.
      leave_integral_schedule[payment_month] ||= BigDecimal("0")
      leave_integral_schedule[payment_month] = total_amount.to_d.round(2)
    end

    # 4) Identify all calendar months covered by the contract
    covered_months = []
    first_month = Date.new(contract_start.year, contract_start.month, 1)
    last_month  = Date.new(contract_end.year, contract_end.month, 1)
    current = first_month
    while current <= last_month
      covered_months << current
      current = current.next_month
    end

    # 5) For each covered month, compute salary_due and each leave mode
    covered_months.each do |month_start|
      # Determine prorated salary for this month
      salary_due = calculate_prorated_salary(month_start)

      # For "10% each month" mode: simply 10% of salary_due
      leave_10pct = (salary_due * 0.10.to_d).round(2)

      # For "1/12" mode: look up in leave_1_12_schedule or zero if not present
      leave_1_12 = leave_1_12_schedule[month_start] || 0.to_d

      # For "full June" mode: look up in leave_integral_schedule or zero if not present
      leave_integral = leave_integral_schedule[month_start] || 0.to_d

      result << {
        month:           month_start,
        salary_due:      salary_due.round(2),
        leave_integral:  leave_integral.round(2),
        leave_1_12:      leave_1_12.round(2),
        leave_10pct:     leave_10pct.round(2)
      }
    end

    result
  end

  private

  # Calculate prorated salary for the given month_start (Date = 1st of month).
  # If the contract covers the full month, return monthly_salary.
  # If partial (first or last month), prorate by (days_covered / days_in_month).
  def calculate_prorated_salary(month_start)
    month_last_day = Date.new(month_start.year, month_start.month, -1)

    # Effective start day for the contract in this month
    effective_start = if month_start.year == contract_start.year && month_start.month == contract_start.month
                        contract_start
    else
                        month_start
    end

    # Effective end day for the contract in this month
    effective_end = if month_start.year == contract_end.year && month_start.month == contract_end.month
                      contract_end
    else
                      month_last_day
    end

    days_covered = (effective_end.day - effective_start.day) + 1
    days_in_month = month_last_day.day

    if days_covered >= days_in_month
      monthly_salary
    else
      (monthly_salary.to_d * days_covered.to_d / days_in_month.to_d).round(2)
    end
  end
end
