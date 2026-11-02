require "rails_helper"

RSpec.describe FliipApi::UserSync::UserUpdater do
  let(:api) { instance_double(FliipApi::ApiClient) }

  before do
    allow(FliipApi::ApiClient).to receive(:new).and_return(api)
    allow(FliipApi::UserSync::ContractSync).to receive(:call)
    allow(FliipApi::UserSync::ServiceSync).to receive(:call)
  end

  it "refreshes a client from the client endpoint" do
    create(:fliip_user, remote_id: 55, user_lastname: "Ancien")
    allow(api).to receive(:fetch_single_user).with(55)
      .and_return(user_id: "55", user_role: "user", user_firstname: "Léa", user_lastname: "Roy")

    message = described_class.call(55)

    expect(FliipUser.find_by!(remote_id: 55).user_lastname).to eq("Roy")
    expect(message).to include("0 new users, 1 updated user")
  end

  it "refreshes a staff member from the staff endpoint" do
    create(:fliip_user, remote_id: 66, user_role: "coach")
    allow(api).to receive(:fetch_single_staff).with(66)
      .and_return(user_id: "66", user_role: "coach", user_firstname: "Jean", user_lastname: "Tremblay")

    described_class.call(66)

    expect(api).to have_received(:fetch_single_staff)
    expect(FliipUser.find_by!(remote_id: 66).user_firstname).to eq("Jean")
  end

  it "treats an unknown remote id as a client and creates it" do
    allow(api).to receive(:fetch_single_user).with(77)
      .and_return(user_id: "77", user_role: "user", user_firstname: "Nouveau", user_lastname: "Client")

    expect { described_class.call(77) }.to change(FliipUser, :count).by(1)
  end
end
