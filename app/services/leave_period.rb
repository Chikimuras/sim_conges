# frozen_string_literal: true

require "date"
require "bigdecimal"
require "bigdecimal/util"

# LeavePeriod represents one "leave-accrual period" for an incomplete-year contract.
# It calculates:
#   • covered_months: all calendar months (Date objects at the first of each month) spanned by this period.
#   • months_worked: total months (float), counting full months as 1.0 and partial months proportionally.
#   • days_acquired: total leave days acquired = ACCRUED_DAYS_PER_FULL_MONTH × months_worked.
#   • value_by_salary_maintain: (monthly_salary / 22) × days_acquired, rounded to 2 decimals.
#   • value_by_10percent: sum of (10% of prorated salary) over all covered months, rounded to 2 decimals.
#   • value_due: maximum of the two valuation methods above.
class LeavePeriod
  # Number of leave days acquired for each full month worked
  ACCRUED_DAYS_PER_FULL_MONTH = 2.5.to_d

  attr_reader :start_date, :end_date, :monthly_salary

  # @param start_date [Date] start of this leave period (inclusive)
  # @param end_date   [Date] end of this leave period (inclusive)
  # @param monthly_salary [BigDecimal, Numeric, String] the fixed gross monthly salary
  def initialize(start_date:, end_date:, monthly_salary:)
    @start_date     = start_date
    @end_date       = end_date
    # Ensure monthly_salary is stored as BigDecimal
    @monthly_salary = monthly_salary.to_d
  end

  # Returns an Array of Date objects (the 1st day of each month)
  # that this period covers, from the month of start_date to the month of end_date.
  def covered_months
    first_month = Date.new(start_date.year, start_date.month, 1)
    last_month  = Date.new(end_date.year, end_date.month, 1)
    months = []
    current = first_month

    while current <= last_month
      months << current
      current = current.next_month
    end

    months
  end

  # Calculates total months worked in this period (Float).
  # - For each month in covered_months:
  #   • If the contract covers the full month, count 1.0
  #   • If it covers only part of the month, count (days_covered / days_in_month).
  #   We round to 4 decimal places for precision.
  def months_worked
    total = 0.0

    covered_months.each do |month_start|
      # Determine the effective start day for this month
      month_effective_start = if month_start.year == start_date.year && month_start.month == start_date.month
                                start_date
      else
                                month_start
      end

      # Determine the effective end day for this month
      month_last_day = Date.new(month_start.year, month_start.month, -1)
      month_effective_end = if month_start.year == end_date.year && month_start.month == end_date.month
                              end_date
      else
                              month_last_day
      end

      days_covered = (month_effective_end.day - month_effective_start.day) + 1
      days_in_month = month_last_day.day

      if days_covered >= days_in_month
        total += 1.0
      else
        total += days_covered.to_f / days_in_month
      end
    end

    total.round(4)
  end

  # Total leave days acquired in this period: ACCRUED_DAYS_PER_FULL_MONTH × months_worked.
  # We round to 4 decimal places for fractional days.
  def days_acquired
    (ACCRUED_DAYS_PER_FULL_MONTH * months_worked.to_d).round(4)
  end

  # Valuation method 1: "maintain salary"
  # Calculate (monthly_salary / 22) × days_acquired, round to 2 decimals.
  def value_by_salary_maintain
    ((monthly_salary / 22.to_d) * days_acquired.to_d).round(2)
  end

  # Valuation method 2: 10% of salaries paid during this period.
  # For each covered month, compute the prorated salary for that month,
  # then take 10% of it. Sum over all months. Round result to 2 decimals.
  def value_by_10percent
    total = 0.to_d

    covered_months.each do |month_start|
      # Effective coverage in this month
      month_last_day = Date.new(month_start.year, month_start.month, -1)

      effective_start = if month_start.year == start_date.year && month_start.month == start_date.month
                          start_date
      else
                          month_start
      end

      effective_end = if month_start.year == end_date.year && month_start.month == end_date.month
                        end_date
      else
                        month_last_day
      end

      days_covered = (effective_end.day - effective_start.day) + 1
      days_in_month = month_last_day.day

      # Prorated salary for these days
      prorated_salary = (monthly_salary * days_covered.to_d / days_in_month.to_d)
      total += (prorated_salary * 0.10.to_d)
    end

    total.round(2)
  end

  # The leave value actually due: pick the higher of the two methods.
  def value_due
    [value_by_salary_maintain, value_by_10percent].max
  end
end
