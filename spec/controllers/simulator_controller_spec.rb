# frozen_string_literal: true

require 'rails_helper'

describe SimulatorController, type: :controller do
  describe 'GET #index' do
    it 'affiche le formulaire' do
      get :index
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end
  end

  describe 'POST #simulate' do
    let(:valid_params) do
      {
        start_date: '2024-04-15',
        end_date: '2024-07-10',
        monthly_salary: '1000'
      }
    end

    it 'calcule et affiche les résultats avec des paramètres valides' do
      post :simulate, params: valid_params
      expect(assigns(:periods)).not_to be_nil
      expect(assigns(:monthly_details)).not_to be_nil
      expect(response).to render_template(:simulate).or render_template(:index)
    end

    it 'affiche une erreur si un champ est manquant' do
      post :simulate, params: valid_params.merge(start_date: '')
      expect(flash.now[:alert]).to eq('Tous les champs sont obligatoires.')
      expect(response).to render_template(:index)
    end

    it 'affiche une erreur si le format de date est invalide' do
      post :simulate, params: valid_params.merge(start_date: '15/04/2024')
      expect(flash.now[:alert]).to eq('Le format des dates doit être AAAA-MM-JJ.')
      expect(response).to render_template(:index)
    end

    it 'affiche une erreur si la date de fin est antérieure à la date de début' do
      post :simulate, params: valid_params.merge(end_date: '2024-03-01')
      expect(flash.now[:alert]).to eq('La date de fin doit être postérieure à la date de début.')
      expect(response).to render_template(:index)
    end

    it 'affiche une erreur si le salaire est non numérique' do
      post :simulate, params: valid_params.merge(monthly_salary: 'abc')
      expect(flash.now[:alert]).to eq('Le salaire doit être un nombre.')
      expect(response).to render_template(:index)
    end

    it 'affiche une erreur si le salaire est négatif' do
      post :simulate, params: valid_params.merge(monthly_salary: '-100')
      expect(flash.now[:alert]).to eq('Le salaire doit être un nombre positif.')
      expect(response).to render_template(:index)
    end

    it 'affiche une erreur si le salaire est hors bornes' do
      post :simulate, params: valid_params.merge(monthly_salary: '1500')
      expect(flash.now[:alert]).to eq('Le salaire doit être compris entre 200 € et 1200 €.')
      expect(response).to render_template(:index)
    end
  end
end
