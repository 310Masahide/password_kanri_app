require "test_helper"

class PwnedPasswordCheckerTest < ActiveSupport::TestCase
  # 本物の API を呼ばずに、決まった返事を返す「にせものの通信」
  class FakeHttp
    attr_reader :requested_path

    def initialize(response)
      @response = response
    end

    def get(path)
      @requested_path = path
      @response
    end
  end

  # Net::HTTP の返事を作る
  def http_response(klass, body)
    response = klass.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  # 「password」を SHA-1 にすると 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8 になる
  test "ハッシュの先頭5文字だけを送り、残りが一致した行の回数を返す" do
    body = "0018A45C4D1DEF81644B54AB7F969B88D65:1\r\n1E4C9B93F3F0682250B6CF8331B7EE68FD8:3861493\r\n"
    fake_http = FakeHttp.new(http_response(Net::HTTPOK, body))

    Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(fake_http) }) do
      assert_equal 3_861_493, PwnedPasswordChecker.count("password")
    end
    assert_equal "/range/5BAA6", fake_http.requested_path
  end

  test "一致する行がなければ、0 を返す" do
    fake_http = FakeHttp.new(http_response(Net::HTTPOK, "0018A45C4D1DEF81644B54AB7F969B88D65:1\r\n"))

    Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(fake_http) }) do
      assert_equal 0, PwnedPasswordChecker.count("password")
    end
  end

  test "API がエラーを返したときは、nil（確認できなかった）を返す" do
    fake_http = FakeHttp.new(http_response(Net::HTTPServiceUnavailable, ""))

    Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(fake_http) }) do
      assert_nil PwnedPasswordChecker.count("password")
    end
  end

  test "つながらないときは、nil（確認できなかった）を返す" do
    Net::HTTP.stub(:start, ->(*_args, **_options) { raise Net::OpenTimeout }) do
      assert_nil PwnedPasswordChecker.count("password")
    end
  end
end
