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
#   • salary_due            => prorated salary for that month
#   • leave_integral        => leave paid in "full payment" mode (either June or final month)
#   • leave_1_12            => leave paid in "1/12 per month" mode
#   • leave_10pct           => leave paid as 10% of that month's salary
#   • leave_regularization  => extra top‐up for "10% with adjustment" when needed
#   • leave_total_10pct     => leave_10pct + leave_regularization
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
      contract_start: contract_start,
      contract_end:   contract_end,
      monthly_salary: monthly_salary
    ).build_periods
  end

  # Returns an Array of Hashes. Each hash corresponds to one calendar month
  # covered by the contract, with keys:
  #   :month               => Date object at the first day of that month
  #   :salary_due          => BigDecimal for prorated salary (rounded to 2 decimals)
  #   :leave_integral      => BigDecimal for leave in "full payment" mode (rounded to 2 decimals)
  #   :leave_1_12          => BigDecimal for leave in "1/12 per month" mode (rounded to 2 decimals)
  #   :leave_10pct         => BigDecimal for leave in "10% of salary" mode (rounded to 2 decimals)
  #   :leave_regularization=> BigDecimal top‐up for "10% adjustment" (rounded to 2 decimals)
  #   :leave_total_10pct   => BigDecimal sum of leave_10pct + leave_regularization (rounded to 2 decimals)
  #
  # IMPORTANT: The last truncated period (if contract ends before May 31) is paid in full on its end month,
  # and does not generate any 1/12 schedule or June payment.
  def calculate_monthly_details
    result = []

    # 1) Precompute value_due for each period (max of the two valuation methods)
    period_totals = {}
    periods.each_with_index do |period, idx|
      period_totals[idx] = period.value_due
    end

    # 2) Identify index of the last truncated period (ends before its natural May 31)
    last_truncated_index = nil
    periods.each_with_index do |period, idx|
      # Compute the "natural end" of this leave period (May 31):
      natural_end = if period.start_date.month >= 6
                      Date.new(period.start_date.year + 1, 5, 31)
      else
                      Date.new(period.start_date.year, 5, 31)
      end

      # If this period ends before its natural_end, and it matches contract_end, it's the last truncated period
      if period.end_date < natural_end && period.end_date == contract_end
        last_truncated_index = idx
      end
    end

    # 3) Build "1/12 per month" schedule for every period EXCEPT the last truncated one
    leave_1_12_schedule = {}
    period_totals.each do |idx, total_amount|
      # Skip the last truncated period entirely
      next if idx == last_truncated_index

      period = periods[idx]

      # Compute the “natural end” (May 31) of this leave‐accrual period:
      #   • If the period began in June or later, natural_end = May 31 of (start_year + 1)
      #   • Otherwise, natural_end = May 31 of start_year
      natural_end = if period.start_date.month >= 6
                      Date.new(period.start_date.year + 1, 5, 31)
      else
                      Date.new(period.start_date.year, 5, 31)
      end

      # The “first payout month” for 1/12 should be the month immediately AFTER that natural_end.
      # That way, if period.end_date = May 31 (full‐year), we start in June; if the period was
      # truncated (but not the last truncated one), its natural_end was still May 31, so we still
      # start in June. This avoids accidentally starting a payout too early.
      first_payout_month = Date.new(natural_end.year, natural_end.month, 1).next_month

      12.times do |i|
        payout_month = first_payout_month >> i
        # Spread total_amount equally over twelve consecutive months:
        leave_1_12_schedule[payout_month] = (total_amount.to_d / 12.to_d).round(2)
      end
    end

    # 4) Build "full payment" schedule for every period
    #    - For normal periods => payment in June following the period end
    #    - For the last truncated period => payment in its final month (contract_end.beginning_of_month)
    leave_integral_schedule = {}
    period_totals.each do |idx, total_amount|
      period = periods[idx]
      # Compute the natural end of the period
      natural_end = if period.start_date.month >= 6
                      Date.new(period.start_date.year + 1, 5, 31)
      else
                      Date.new(period.start_date.year, 5, 31)
      end

      if idx == last_truncated_index
        # Pay the entire amount in the contract_end month
        pay_month = Date.new(contract_end.year, contract_end.month, 1)
        leave_integral_schedule[pay_month] = total_amount.to_d.round(2)
      else
        # Pay in the month after period.end_date (always a June)
        pay_month = Date.new(period.end_date.year, period.end_date.month, 1).next_month
        leave_integral_schedule[pay_month] = total_amount.to_d.round(2)
      end
    end

    # 5) List all calendar months covered by the contract (1st day of each month)
    covered_months = []
    first_month = Date.new(contract_start.year, contract_start.month, 1)
    last_month  = Date.new(contract_end.year, contract_end.month, 1)
    current = first_month
    while current <= last_month
      covered_months << current
      current = current.next_month
    end

    # 6) For each covered month, compute salary_due and each leave mode
    covered_months.each do |month_start|
      salary_due = calculate_prorated_salary(month_start)

      # (a) 10% of this month's salary
      leave_10pct = salary_due * 0.10.to_d

      # (b) “1/12 per month” lookup or zero
      leave_1_12 = leave_1_12_schedule[month_start] || 0.to_d

      # (c) “full payment” lookup or zero
      leave_integral = leave_integral_schedule[month_start] || 0.to_d

      # (d) “10% adjustment” pour le dernier mois tronqué ou paiement de juin
      leave_regularization = 0.to_d

      if leave_integral_schedule.key?(month_start)
        # Find which period this payment corresponds to
        matching_period_index = periods.index do |p|
          # Normal period: payment was scheduled in June after p.end_date
          jun_payment_month = Date.new(p.end_date.year, p.end_date.month, 1).next_month
          # Last truncated period: payment was scheduled exactly on contract_end.beginning_of_month
          last_payment_month = Date.new(contract_end.year, contract_end.month, 1)
          (jun_payment_month == month_start) || (idx_of_last_truncated?(p) && last_payment_month == month_start)
        end

        if matching_period_index
          period = periods[matching_period_index]

          if matching_period_index == last_truncated_index
            # Last truncated period: use "salary-maintain" valuation minus sum of 10% monthly payments
            vsal = (monthly_salary.to_d / 22.to_d) * (2.5.to_d * period.months_worked.to_d)
            vsal = vsal.round(2)

            # Count how many full months are in this truncated period
            full_months_in_truncated = (covered_months_for(period.start_date, period.end_date).count)

            # Sum of 10% already paid for each full month
            sum_10pct_paid = (monthly_salary.to_d * 0.10.to_d * full_months_in_truncated).round(2)

            leave_regularization = (vsal - sum_10pct_paid).round(2)
          else
            # Normal period: adjust so that total 10% = value_by_salary_maintain
            total_10pct_due = value_by_10percent(period.start_date, period.end_date, monthly_salary)
            # Sum of the 10% monthly amounts already paid
            sum_paid = covered_months_for(period.start_date, period.end_date).sum do |sub_month|
              prorated = calculate_prorated_salary_for_period_month(period, sub_month)
              (prorated * 0.10.to_d).round(2)
            end
            leave_regularization = (total_10pct_due - sum_paid).round(2)
          end
        end
      end

      # (e) Total 10% = monthly 10% + any adjustment (only in June or final month)
      leave_total_10pct = leave_10pct + leave_regularization

      # Append this month’s data to results
      result << {
        month:                month_start,
        salary_due:           salary_due,
        leave_integral:       leave_integral,
        leave_1_12:           leave_1_12,
        leave_10pct:          leave_10pct,
        leave_regularization: leave_regularization,
        leave_total_10pct:    leave_total_10pct
      }
    end

    result
  end

  private

  # Calculate prorated salary for a given month_start (first day of month).
  # If the contract covers the entire month, return monthly_salary.
  # Otherwise, prorate by (days_covered / days_in_month).
  def calculate_prorated_salary(month_start)
    month_last_day = Date.new(month_start.year, month_start.month, -1)

    effective_start = if month_start.year == contract_start.year && month_start.month == contract_start.month
                        contract_start
    else
                        month_start
    end

    effective_end = if month_start.year == contract_end.year && month_start.month == contract_end.month
                      contract_end
    else
                      month_last_day
    end

    days_covered = (effective_end.day - effective_start.day) + 1
    dim = month_last_day.day

    if days_covered >= dim
      monthly_salary
    else
      (monthly_salary.to_d * days_covered.to_d / dim.to_d).round(2)
    end
  end

  # Return an Array of month-start Dates for a given period (inclusive).
  def covered_months_for(period_start, period_end)
    months = []
    current = Date.new(period_start.year, period_start.month, 1)
    last = Date.new(period_end.year, period_end.month, 1)

    while current <= last
      months << current
      current = current.next_month
    end

    months
  end

  # Calculate prorated salary for a given month within a specific LeavePeriod.
  # (Same logic as calculate_prorated_salary, but restricted to that LeavePeriod).
  def calculate_prorated_salary_for_period_month(period, month_start)
    month_last_day = Date.new(month_start.year, month_start.month, -1)

    effective_start = if month_start.year == period.start_date.year && month_start.month == period.start_date.month
                        period.start_date
    else
                        month_start
    end

    effective_end = if month_start.year == period.end_date.year && month_start.month == period.end_date.month
                      period.end_date
    else
                      month_last_day
    end

    days_covered = (effective_end.day - effective_start.day) + 1
    dim = month_last_day.day

    if days_covered >= dim
      monthly_salary
    else
      (monthly_salary.to_d * days_covered.to_d / dim.to_d).round(2)
    end
  end

  # Return true if the given period is the last truncated period (ends before its natural May 31).
  def idx_of_last_truncated?(period)
    natural_end = if period.start_date.month >= 6
                    Date.new(period.start_date.year + 1, 5, 31)
    else
                    Date.new(period.start_date.year, 5, 31)
    end

    period.end_date < natural_end && period.end_date == contract_end
  end

  # Delegate to LeavePeriod’s 10% valuation method for simplicity.
  def value_by_10percent(start_date, end_date, monthly_salary)
    LeavePeriod.new(
      start_date:     start_date,
      end_date:       end_date,
      monthly_salary: monthly_salary
    ).value_by_10percent
  end
end
