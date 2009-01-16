class Moonshine::Manifest::Rails < Moonshine::Manifest
  requires [
    :user,
    :ruby,
    :rubygems,
    :db,
    :web,
    :rails,
    :deploy
  ]
  provides :user, 'rails'
  provides :ruby, 'enterprise'
  provides :rubygems, 'enterprise'
  provides :db, 'mysql'
  provides :rails, 'passenger'
  provides :deploy, 'git'
end