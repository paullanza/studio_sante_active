require "rails_helper"

# GEKO installs as a full-screen web app from public/manifest.json.
RSpec.describe "Web app manifest", type: :request do
  let(:manifest) { JSON.parse(Rails.root.join("public/manifest.json").read) }

  it "opens full screen as GEKO" do
    expect(manifest).to include("name" => "GEKO · Studio Santé Active", "short_name" => "GEKO",
                                "display" => "standalone", "start_url" => "/", "lang" => "fr-CA")
  end

  it "points at icons that exist" do
    manifest["icons"].each do |icon|
      expect(Rails.public_path.join(icon["src"].delete_prefix("/"))).to be_file
    end
    expect(manifest["icons"].pluck("purpose")).to include("maskable")
  end

  it "is linked from the new layout" do
    get new_user_session_path

    expect(response.body).to include('rel="manifest" href="/manifest.json"')
  end
end
