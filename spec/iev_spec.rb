# frozen_string_literal: true

RSpec.describe Iev do
  before :each do
    FileUtils.rm_rf %w[testcache testcache2]
    @db = Iev::Db.new "testcache", "testcache2"
  end

  it "has a version number" do
    expect(Iev::VERSION).not_to be nil
  end

  it "get term, cache it and return" do
    mock_open_uri("103-01-02")
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
    mock_open_uri("103-08-14")
    term = @db.fetch "103-08-14", "en"
    expect(term).to eq "p-fractile"
  end

  it "return empty string if code not found" do
    mock_open_uri("111-11-11")
    term = @db.fetch "111-11-11", "en"
    expect(term).to eq ""
    id = "111-11-11/en"
    testcache = @db.instance_variable_get :@db
    expect(testcache.fetched(id)).to be_nil
    expect(testcache[id]).to eq ""
  end

  it "return nil if lang not found" do
    mock_open_uri("103-01-02")
    term = @db.fetch "103-01-02", "eee"
    expect(term).to eq nil
    id = "103-01-02/eee"
    testcache = @db.instance_variable_get :@db
    expect(testcache[id]).to eq nil
  end

  it "shoudl clear global cache if version is changed" do
    mock_open_uri("103-01-02")
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

  def mock_open_uri(code)
    expect(OpenURI).to receive(:open_uri).and_wrap_original do |m, *args|
      expect(args[0]).to be_instance_of String
      file = "spec/examples/#{code.tr('-', '_')}.html"
      File.write file, m.call(*args).read unless File.exist? file
      File.read file
    end
  end
end
