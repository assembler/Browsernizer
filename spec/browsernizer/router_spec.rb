require 'spec_helper'

describe Browsernizer::Router do

  let(:app) { double }

  subject do
    Browsernizer::Router.new(app) do |config|
      config.supported do |browser|
        true if browser.user_agent.include?('Spec')
      end
      config.supported "Firefox", false
      config.supported "Chrome", "7.1"
      config.supported do |browser|
        !(browser.safari? && browser.mobile?)
      end
    end
  end

  let(:default_env) do
    {
      "HTTP_USER_AGENT" => chrome_agent("7.1.1"),
      "PATH_INFO" => "/index"
    }
  end

  context "All Good" do
    it "propagates request with updated env" do
      expect(app).to receive(:call) do |env|
        expect(env['browsernizer']['supported']).to be_truthy
        expect(env['browsernizer']['browser']).to eq("Chrome")
        expect(env['browsernizer']['version']).to eq("7.1.1")
      end
      subject.call(default_env)
    end
  end


  shared_examples "unsupported browser" do
    context "location not set" do
      it "propagates request with updated env" do
        expect(app).to receive(:call) do |env|
          expect(env['browsernizer']['supported']).to be_falsey
        end
        subject.call(@env)
      end
    end

    context "location is set" do
      before do
        subject.config.location "/browser.html"
      end

      it "prevents propagation" do
        expect(app).not_to receive(:call)
        subject.call(@env)
      end

      it "redirects to proper location" do
        response = subject.call(@env)
        expect(response[0]).to eq(307)
        expect(response[1]["Location"]).to eq("/browser.html")
      end

      context "Excluded path" do
        before do
          subject.config.exclude %r{^/assets}
          @env = @env.merge({
            "PATH_INFO" => "/assets/foo.jpg",
          })
        end
        it "propagates request" do
          expect(app).to receive(:call).with(@env)
          subject.call(@env)
        end
      end

      context "Already on /browser.html page" do
        before do
          @env = @env.merge({
            "PATH_INFO" => "/browser.html"
          })
        end
        it "propagates request with updated env" do
          expect(app).to receive(:call) do |env|
            expect(env['browsernizer']['supported']).to be_falsey
          end
          subject.call(@env)
        end
      end
    end
  end

  context "Unsupported Version" do
    before do
      @env = default_env.merge({
        "HTTP_USER_AGENT" => chrome_agent("7")
      })
    end
    it_behaves_like "unsupported browser"
  end

  context "Unsupported Vendor" do
    before do
      @env = default_env.merge({
        "HTTP_USER_AGENT" => firefox_agent("10.0.1")
      })
    end
    it_behaves_like "unsupported browser"
  end

  context "Unsupported by proc" do
    before do
      @env = default_env.merge({
        "HTTP_USER_AGENT" => mobile_safari_agent
      })
    end
    it_behaves_like "unsupported browser"
  end

  context "Supported by proc" do
    before do
      @env = default_env.merge({
        "HTTP_USER_AGENT" => firefox_agent("10.0.1") + ' Spec'
      })
    end

    it "propagates request" do
      expect(app).to receive(:call) do |env|
        expect(env['browsernizer']['supported']).to be_truthy
      end
      subject.call(@env)
    end
  end

  def chrome_agent(version)
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_2) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/#{version} Safari/535.7"
  end

  def firefox_agent(version)
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:10.0.1) Gecko/20100101 Firefox/#{version}"
  end

  def mobile_safari_agent
    "Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420.1 (KHTML, like Gecko) Version/3.0 Mobile/4A102 Safari/419"
  end

end
