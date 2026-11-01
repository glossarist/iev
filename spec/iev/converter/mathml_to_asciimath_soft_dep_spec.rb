# frozen_string_literal: true

require "iev"

# Plurimath is a soft dependency (lib/iev.rb loads it when the bundle
# resolves it). The MathML conversion must degrade to a no-op — not
# raise NameError from its own rescue clause — in environments where
# the bundle dropped it (the CI dependent leg's mml/lutaml-model
# transitive clash).
RSpec.describe Iev::Converter::MathmlToAsciimath do
  it "degrades to no-op when plurimath cannot be loaded" do
    input = '<math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi></math>'
    converted = nil
    hide_const("Plurimath::Math") if defined?(Plurimath::Math)
    allow_any_instance_of(described_class).to receive(:require)
      .with("plurimath").and_raise(LoadError, "dropped by the bundle")

    converted = described_class.convert(input)

    expect(converted).not_to include("<math>")
  end
end
