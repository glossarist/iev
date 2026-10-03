# frozen_string_literal: true

# Temporary diagnostic for the windows-only ISO 639 table failures.
# Prints platform facts; asserts nothing. Remove once diagnosed.
RSpec.describe "ISO 639 table diagnosis" do
  it "prints table state" do
    path = File.join(__dir__, "..", "lib", "iev", "iso_639_2.yaml")
    raw = File.binread(path)
    puts "DIAG platform=#{RUBY_PLATFORM} ruby=#{RUBY_VERSION}"
    puts "DIAG psych=#{Psych::VERSION} safe_load_file owner=#{YAML.method(:safe_load_file).owner}"
    puts "DIAG file bytes=#{raw.bytesize} first8=#{raw.bytes.first(8).inspect} crlf=#{raw.include?("\r\n")}"
    table = Iev::Iso639Code::COUNTRY_CODES
    puts "DIAG table class=#{table.class} size=#{(table.size if table.respond_to?(:size)).inspect}"
    if table.is_a?(::Hash)
      k, v = table.first
      puts "DIAG first key=#{k.inspect} key_enc=#{k.encoding if k.is_a?(String)}"
      puts "DIAG first value class=#{v.class} value=#{v.inspect[0, 100]}"
      eng = table["eng"] || table[:eng]
      puts "DIAG eng iso_639_1=#{(eng["iso_639_1"] if eng.is_a?(::Hash)).inspect}"
      if eng.is_a?(::Hash)
        s = eng["iso_639_1"]
        puts "DIAG eq en=#{(s == "en").inspect} s_enc=#{(s.encoding if s.is_a?(String)).inspect} t=#{eng["terminology"].inspect} t_class=#{eng["terminology"].class}"
      end
    end
    begin
      r = Iev::Iso639Code.three_char_code("en")
      puts "DIAG three_char_code(en)=#{r.inspect[0, 80]}"
    rescue StandardError => e
      puts "DIAG three_char_code(en) raised #{e.class}: #{e.message}"
    end
  end
end
