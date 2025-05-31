# frozen_string_literal: true

require 'rails_helper'

describe LeavePeriod do
  let(:start_date) { Date.new(2024, 4, 15) }
  let(:end_date)   { Date.new(2024, 6, 10) }
  let(:salary)     { 1000 }
  subject { described_class.new(start_date: start_date, end_date: end_date, monthly_salary: salary) }

  it 'calcule les mois couverts' do
    expect(subject.covered_months).to eq([
      Date.new(2024, 4, 1),
      Date.new(2024, 5, 1),
      Date.new(2024, 6, 1)
    ])
  end

  it 'calcule un nombre de mois travaillé > 0' do
    expect(subject.months_worked).to be > 0
  end

  it 'calcule des jours acquis > 0' do
    expect(subject.days_acquired).to be > 0
  end

  it 'calcule une valeur due cohérente' do
    expect(subject.value_due).to be >= 0
  end

  it 'calcule exactement le nombre de mois travaillé attendu' do
    # Avril 15-30 (16j/30), Mai (31j/31), Juin 1-10 (10j/30)
    expected = (16.0/30.0) + 1.0 + (10.0/30.0)
    expect(subject.months_worked).to be_within(0.0001).of(expected)
  end

  it 'calcule exactement le nombre de jours acquis attendu' do
    expected = 2.5 * subject.months_worked
    expect(subject.days_acquired).to be_within(0.0001).of(expected)
  end

  it 'calcule la valorisation "maintien salaire" attendue' do
    expected = ((salary.to_d / 22) * subject.days_acquired).round(2)
    expect(subject.value_by_salary_maintain).to eq(expected)
  end

  it 'calcule la valorisation "10%" attendue' do
    total = 0.to_d
    subject.covered_months.each do |month_start|
      month_last_day = Date.new(month_start.year, month_start.month, -1)
      effective_start = (month_start.year == start_date.year && month_start.month == start_date.month) ? start_date : month_start
      effective_end = (month_start.year == end_date.year && month_start.month == end_date.month) ? end_date : month_last_day
      days_covered = (effective_end.day - effective_start.day) + 1
      days_in_month = month_last_day.day
      prorated_salary = (salary.to_d * days_covered.to_d / days_in_month.to_d)
      total += (prorated_salary * 0.10.to_d)
    end
    expect(subject.value_by_10percent).to eq(total.round(2))
  end

  it 'choisit la valorisation la plus élevée pour value_due' do
    expect(subject.value_due).to eq([ subject.value_by_salary_maintain, subject.value_by_10percent ].max)
  end

  context 'cas limite : période sur un mois complet' do
    let(:start_date) { Date.new(2024, 5, 1) }
    let(:end_date)   { Date.new(2024, 5, 31) }
    it 'compte bien 1 mois travaillé' do
      expect(subject.months_worked).to eq(1.0)
      expect(subject.days_acquired).to eq(2.5)
    end
  end

  context 'période couvrant plusieurs années' do
    let(:start_date) { Date.new(2023, 12, 15) }
    let(:end_date)   { Date.new(2024, 2, 10) }
    it 'calcule les mois couverts sur deux années' do
      expect(subject.covered_months).to eq([
        Date.new(2023, 12, 1),
        Date.new(2024, 1, 1),
        Date.new(2024, 2, 1)
      ])
    end
  end
end
