require File.expand_path('../helper', __FILE__)

class TestCampfire < CC::Service::TestCase
  def test_config
    assert_raises CC::Service::ConfigurationError do
      service(CC::Service::Campfire, :coverage, {},{})
    end
  end

  def test_test_hook
    assert_campfire_receives(
      :test,
      { repo_name: "Rails" },
      "[Code Climate][Rails] This is a test of the Campfire service hook"
    )
  end

  def test_coverage_improved
    assert_campfire_receives(:coverage, {
      repo_name: "Rails",
      covered_percent: 90.2,
      previous_covered_percent: 80.0,
      covered_percent_delta: 10.2,
      details_url: "http://codeclimate.com/rails/compare"
    }, [
      "[Code Climate][Rails] :sunny:",
      "Test coverage has improved to 90.2% (+10.2%).",
      "(http://codeclimate.com/rails/compare)"
    ].join(" "))
  end

  def test_coverage_declined
    assert_campfire_receives(:coverage, {
      repo_name: "jQuery",
      covered_percent: 88.6,
      previous_covered_percent: 94.6,
      covered_percent_delta: -6.0,
      details_url: "http://codeclimate.com/rails/compare"
    }, [
      "[Code Climate][jQuery] :umbrella:",
      "Test coverage has declined to 88.6% (-6.0%).",
      "(http://codeclimate.com/rails/compare)"
    ].join(" "))
  end

  def test_quality_improved
    assert_campfire_receives(:quality, {
      repo_name: "Rails",
      constant_name: "User",
      rating: "A",
      previous_rating: "B",
      remediation_cost: 50,
      previous_remediation_cost: 25,
      details_url: "http://codeclimate.com/rails/feed"
    }, [
      "[Code Climate][Rails] :sunny:",
      "User has improved from a B to an A.",
      "(http://codeclimate.com/rails/feed)"
    ].join(" "))
  end

  def test_quality_declined
    assert_campfire_receives(:quality, {
      repo_name: "Rails",
      constant_name: "User",
      rating: "D",
      previous_rating: "C",
      remediation_cost: 25,
      previous_remediation_cost: 50,
      details_url: "http://codeclimate.com/rails/feed"
    }, [
      "[Code Climate][Rails] :umbrella:",
      "User has declined from a C to a D.",
      "(http://codeclimate.com/rails/feed)"
    ].join(" "))
  end

  def test_single_vulnerability
    assert_campfire_receives(:vulnerability, {
      repo_name: "Rails",
      vulnerabilities: [{ "warning_type" => "critical" }],
      details_url: "https://codeclimate.com/repos/1/vulnerabilities"
    }, [
      "[Code Climate][Rails]",
      "New critical issue found.",
      "Details: https://codeclimate.com/repos/1/vulnerabilities"
    ].join(" "))
  end

  def test_single_vulnerability_with_location
    assert_campfire_receives(:vulnerability, {
      repo_name: "Rails",
      vulnerabilities: [{
        "warning_type" => "critical",
        "location" => "app/user.rb line 120"
      }],
      details_url: "https://codeclimate.com/repos/1/vulnerabilities"
    }, [
      "[Code Climate][Rails]",
      "New critical issue found",
      "in app/user.rb line 120.",
      "Details: https://codeclimate.com/repos/1/vulnerabilities"
    ].join(" "))
  end

  def test_multiple_vulnerabilities
    assert_campfire_receives(:vulnerability, {
      repo_name: "Rails",
      warning_type: "critical",
      vulnerabilities: [{
        "warning_type" => "unused",
        "location" => "unused"
      }, {
        "warning_type" => "unused",
        "location" => "unused"
      }],
      details_url: "https://codeclimate.com/repos/1/vulnerabilities"
    }, [
      "[Code Climate][Rails]",
      "2 new critical issues found.",
      "Details: https://codeclimate.com/repos/1/vulnerabilities"
    ].join(" "))
  end

  private

  def assert_campfire_receives(event_name, event_data, expected_body)
    @stubs.post '/room/123/speak.json' do |env|
      body = JSON.parse(env[:body])
      assert_equal expected_body, body["message"]["body"]
      [200, {}, '']
    end

    receive(
      CC::Service::Campfire,
      event_name,
      { token: "token", subdomain: "sub", room_id: "123" },
      event_data
    )
  end
end
