RSpec.describe Iev do
  it "has a version number" do
    expect(Iev::VERSION).not_to be nil
  end

  it "return term" do
    mock_open_uri("103-01-02")
    term = Iev.get "103-01-02", "en"
    expect(term).to eq "functional"
  end

  it "return empty string if code not found" do
    mock_open_uri("111-11-11")
    term = Iev.get "111-11-11", "en"
    expect(term).to eq ""
  end

  it "return nil if lang not found" do
    mock_open_uri("103-01-02")
    term = Iev.get "103-01-02", "eee"
    expect(term).to eq nil
  end
  
  
  private

  def mock_open_uri(code)
    expect(OpenURI).to receive(:open_uri).and_wrap_original do |m, *args|
      expect(args[0]).to be_instance_of String
      file = "spec/examples/#{code.gsub("-", "_")}.html"
      File.write file, m.call(*args).read unless File.exist? file
      File.read file
    end
  end
  
end
