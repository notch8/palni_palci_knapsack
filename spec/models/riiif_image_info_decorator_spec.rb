# frozen_string_literal: true

RSpec.describe RiiifImageInfoDecorator do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'oriented.jpg') }
  let(:orientation) { 6 }
  let(:autorotate) { true }
  let(:file) { Riiif::File.new(path) }
  let(:image) { Riiif::Image.new('id', file) }

  before do
    Vips::Image.black(300, 200, bands: 3).mutate { |m| m.set_type!(GObject::GINT_TYPE, 'orientation', orientation) }.write_to_file(path)
    allow(Riiif).to receive_messages(autorotate?: autorotate, use_vips?: true)
    allow(Riiif::Image).to receive(:info_service).and_return(->(_id, _file) { { width: 300, height: 200, format: 'image/jpeg', channels: 'srgb' } })
  end

  after { FileUtils.remove_entry(dir) }

  it 'swaps width and height for a 90 degree orientation' do
    expect(image.info).to have_attributes(width: 200, height: 300, format: 'image/jpeg', channels: 'srgb')
  end

  context 'with a 180 degree orientation' do
    let(:orientation) { 3 }

    it 'keeps the stored dimensions' do
      expect(image.info).to have_attributes(width: 300, height: 200)
    end
  end

  context 'when autorotate is disabled' do
    let(:autorotate) { false }

    it 'keeps the stored dimensions' do
      expect(image.info).to have_attributes(width: 300, height: 200)
    end
  end
end
