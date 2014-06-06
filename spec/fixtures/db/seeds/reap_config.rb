Sprig::Harvest.configure do |config|
  config.env           = 'dreamland'
  config.limit         = 30
  config.ignored_attrs = [:created_at, :updated_at]

  config.models = [
    {
      :class         => User,
      :collection    => User.where(last_name: 'Janglez'),
      :limit         => 10,
      :ignored_attrs => :type
    },

    {
      :class      => Post,
      :limit      => 20
    },

    Comment
  ]
end
