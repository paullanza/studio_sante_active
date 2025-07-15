class CreateFliipUsers < FliipApiCaller
  def self.call
    new.create_all_users
  end

  def create_all_users
    @api_client.fetch_users.each do |data|
      create_user(data)
    end
  end
end
