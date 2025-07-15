class AddNewFliipUsers < FliipApiCaller
  def self.call
    new.create_new_users
  end

  def create_new_users
    users = @api_client.fetch_users(20)
    new_users = users.select { |data| data[:user_id].to_i > @last_remote_id }

    new_users.each do |data|
      create_user(data)
    end
  end
end
