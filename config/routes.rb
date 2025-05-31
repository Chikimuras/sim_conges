Rails.application.routes.draw do
   # Defines the root path route ("/")
   root "simulator#index"
   post "/simulate" => "simulator#simulate", as: :simulate
end
