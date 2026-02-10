# frozen_string_literal: true

RSpec.describe Iev do
  before :each do
    FileUtils.rm_rf %w[testcache testcache2]
    @db = Iev::Db.new "testcache", "testcache2"
  end

  it "has a version number" do
    expect(Iev::VERSION).not_to be nil
  end

  it "should handle empty cache directory gracefully" do
    # Simulate fresh installation with empty cache
    cache_dir = "testcache_empty_#{Time.now.to_i}"
    FileUtils.rm_rf(cache_dir) if Dir.exist?(cache_dir)

    # This should not raise an exception
    expect do
      db = Iev::Db.new(cache_dir, nil)
      expect(db).not_to be_nil
    end.not_to raise_error

    # Cleanup
    FileUtils.rm_rf(cache_dir) if Dir.exist?(cache_dir)
  end

  it "should handle non-existent cache directory gracefully" do
    # Use a path that doesn't exist
    cache_dir = "/tmp/iev_test_nonexistent_#{Time.now.to_i}"

    # This should not raise an exception
    expect do
      db = Iev::Db.new(cache_dir, nil)
      expect(db).not_to be_nil
      expect(Dir.exist?(cache_dir)).to be_truthy
    end.not_to raise_error

    # Cleanup
    FileUtils.rm_rf(cache_dir) if Dir.exist?(cache_dir)
  end

  it "get term, cache it and return" do
    mock_mechanize("103-01-02")
    term = @db.fetch "103-01-02", "en"
    expect(term).to eq "functional"
    id = "103-01-02/en"
    testcache = @db.instance_variable_get :@db
    expect(testcache.fetched(id)).to be_nil
    expect(testcache[id]).to eq "functional"
    testcache = @db.instance_variable_get :@local_db
    expect(testcache[id]).to eq "functional"
    expect(File.exist?("testcache")).to be_truthy
    expect(File.exist?("testcache2")).to be_truthy
  end

  # <td><b><i>p</i>-fractile</b>, &lt;of a probability distribution&gt;<br><b><i>p</i>-quantile</b>, &lt;of a probability distribution&gt;</td>
  it "strips extraneous information from term" do
    mock_mechanize("103-08-14")
    term = @db.fetch "103-08-14", "en"
    expect(term).to eq "p-fractile"
  end

  it "return empty string if code not found" do
    mock_mechanize("111-11-11")
    term = @db.fetch "111-11-11", "en"
    expect(term).to eq ""
    id = "111-11-11/en"
    testcache = @db.instance_variable_get :@db
    expect(testcache.fetched(id)).to be_nil
    expect(testcache[id]).to eq ""
  end

  it "return nil if lang not found" do
    mock_mechanize("103-01-02")
    term = @db.fetch "103-01-02", "eee"
    expect(term).to eq nil
    id = "103-01-02/eee"
    testcache = @db.instance_variable_get :@db
    expect(testcache[id]).to eq nil
  end

  it "shoudl clear global cache if version is changed" do
    mock_mechanize("103-01-02")
    @db.fetch "103-01-02", "en"
    expect(@db.instance_variable_get(:@db).all.any?).to be_truthy
    stub_const "Iev::VERSION", "new_version"
    db = Iev::Db.new "testcache", "testcache2"
    testcache = db.instance_variable_get :@db
    expect(testcache.all.any?).to be_falsey
    testcache = db.instance_variable_get :@local_db
    expect(testcache).to be_nil
  end

  it "local cache should overrade global" do
    id = "103-01-02/en"
    testcache = @db.instance_variable_get :@db
    testcache[id] = "global"
    term = @db.fetch "103-01-02", "en"
    expect(term).to eq "global"
    testcache = @db.instance_variable_get :@local_db
    testcache[id] = "local"
    term = @db.fetch "103-01-02", "en"
    expect(term).to eq "local"
  end

  it "delete entry" do
    testcache = @db.instance_variable_get :@db
    # save_entry "test key", "test value"
    testcache["test key"] = "test value"
    expect(testcache["test key"]).to eq "test value"
    expect(testcache["not existed key"]).to be_nil
    testcache = Iev::DbCache.new "testcache"
    testcache.delete("test_key")
    testcache2 = Iev::DbCache.new "testcache2"
    testcache2.delete("test_key")
    expect(testcache["test key"]).to be_nil
  end

  private

  def mock_mechanize(code)
    return
    # Create mock objects
    mock_page = double("Mechanize::Page")
    mock_agent = double("Mechanize")

    # Set up the mock chain
    allow(Mechanize).to receive(:new).and_return(mock_agent)
    allow(mock_agent).to receive(:user_agent=)

    allow(mock_agent).to receive(:get) do |url|
      expect(url).to be_instance_of String
      file = "spec/examples/#{code.tr('-', '_')}.html"

      # If file doesn't exist, fetch it from the real site
      unless File.exist?(file)
        real_agent = Mechanize.new
        real_agent.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        real_page = real_agent.get(url)
        File.write(file, real_page.body)
      end

      # Return mock page with the HTML content
      html_content = File.read(file)
      allow(mock_page).to receive(:parser).and_return(Nokogiri::HTML(html_content, nil, "UTF-8"))
      mock_page
    end
  end
end
