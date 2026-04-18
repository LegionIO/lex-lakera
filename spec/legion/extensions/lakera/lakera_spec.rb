# frozen_string_literal: true

RSpec.describe Legion::Extensions::Lakera do
  it 'has a version number' do
    expect(Legion::Extensions::Lakera::VERSION).not_to be_nil
  end

  it 'version is a string' do
    expect(Legion::Extensions::Lakera::VERSION).to be_a(String)
  end

  it 'exposes the Client class' do
    expect(Legion::Extensions::Lakera::Client).to be_a(Class)
  end
end
