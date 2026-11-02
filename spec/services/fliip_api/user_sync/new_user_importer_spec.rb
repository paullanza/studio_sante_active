require "rails_helper"

RSpec.describe FliipApi::UserSync::NewUserImporter do
  let(:api) { instance_double(FliipApi::ApiClient) }

  def api_user(id, role: "user")
    { user_id: id.to_s, user_role: role, user_firstname: "Prénom #{id}", user_lastname: "Nom" }
  end

  before do
    allow(FliipApi::ApiClient).to receive(:new).and_return(api)
    allow(FliipApi::UserSync::ContractSync).to receive(:call)
    allow(FliipApi::UserSync::ServiceSync).to receive(:call)
    allow(api).to receive(:fetch_all_staff).and_return([])
  end

  it "imports only clients newer than the highest stored remote id" do
    create(:fliip_user, remote_id: 100, user_lastname: "Existant")
    allow(api).to receive(:fetch_all_users).and_return([api_user(99), api_user(100), api_user(101), api_user(102)])

    message = described_class.call

    expect(FliipUser.pluck(:remote_id)).to contain_exactly(100, 101, 102)
    expect(FliipUser.find_by!(remote_id: 100).user_lastname).to eq("Existant")
    expect(message).to include("2 new users, 0 updated users")
  end

  it "imports every client into an empty database" do
    allow(api).to receive(:fetch_all_users).and_return([api_user(1), api_user(2)])

    expect { described_class.call }.to change(FliipUser, :count).by(2)
  end

  it "imports staff members that are not stored yet and skips known ones" do
    create(:fliip_user, remote_id: 5000, user_role: "coach")
    allow(api).to receive(:fetch_all_users).and_return([])
    allow(api).to receive(:fetch_all_staff).and_return([api_user(5000, role: "coach"), api_user(5001, role: "admin")])

    described_class.call

    expect(FliipUser.find_by!(remote_id: 5001)).to be_staff
    expect(FliipApi::UserSync::ServiceSync).to have_received(:call).once
  end
end
