RSpec.describe Iev do
  before :each do
    system 'rm testcache testcache2'
    @db = Iev::Db.new 'testcache', 'testcache2'
  end

  it 'has a version number' do
    expect(Iev::VERSION).not_to be nil
  end

  it 'get term, cache it and return' do
    mock_open_uri('103-01-02')
    term = @db.fetch '103-01-02', 'en'
    expect(term).to eq 'functional'
    id = '103-01-02/en'
    testcache = @db.instance_variable_get :@db
    testcache.transaction { expect(testcache[id]['term']).to eq 'functional' }
    testcache = @db.instance_variable_get :@local_db
    testcache.transaction { expect(testcache[id]['term']).to eq 'functional' }
    expect(File.exist?('testcache')).to be_truthy
    expect(File.exist?('testcache2')).to be_truthy
  end

  it 'return empty string if code not found' do
    mock_open_uri('111-11-11')
    term = @db.fetch '111-11-11', 'en'
    expect(term).to eq ''
    id = '111-11-11/en'
    testcache = @db.instance_variable_get :@db
    testcache.transaction { expect(testcache[id]['term']).to eq '' }
  end

  it 'return nil if lang not found' do
    mock_open_uri('103-01-02')
    term = @db.fetch '103-01-02', 'eee'
    expect(term).to eq nil
    id = '103-01-02/eee'
    testcache = @db.instance_variable_get :@db
    testcache.transaction { expect(testcache[id]['term']).to eq nil }
  end

  it 'shoudl clear global cache if version is changed' do
    mock_open_uri('103-01-02')
    _term = @db.fetch '103-01-02', 'en'
    stub_const 'Iev::VERSION', 'new_version'
    id = '103-01-02/en'
    db = Iev::Db.new 'testcache', 'testcache2'
    testcache = db.instance_variable_get :@db
    testcache.transaction do
      expect(testcache.root?(id)).to be_falsey
    end
    testcache = db.instance_variable_get :@local_db
    expect(testcache).to be_nil
  end

  it 'local cache should overrade global' do
    id = '103-01-02/en'
    testcache = @db.instance_variable_get :@db
    testcache.transaction do
      testcache[id] = { 'term' => 'global', 'definition' => nil }
    end
    term = @db.fetch '103-01-02', 'en'
    expect(term).to eq 'global'
    testcache = @db.instance_variable_get :@local_db
    testcache.transaction do
      testcache[id] = { 'term' => 'local', 'definition' => nil }
    end
    term = @db.fetch '103-01-02', 'en'
    expect(term).to eq 'local'
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
