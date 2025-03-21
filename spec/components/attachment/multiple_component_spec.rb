# frozen_string_literal: true

RSpec.describe Attachment::MultipleComponent, type: :component do
  let(:procedure) { create(:procedure, :published, types_de_champ_public:) }
  let(:types_de_champ_public) { [{ type: :titre_identite }] }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:champ) { dossier.champs.first }

  let(:attached_file) { champ.piece_justificative_file }
  let(:kwargs) { {} }

  let(:component) do
    described_class.new(
      champ:,
      attached_file:,
      **kwargs
    )
  end

  subject { render_inline(component).to_html }

  context 'when there is no attachment yet' do
    let(:dossier) { create(:dossier, procedure:) }

    it 'renders a form field for uploading a file and max attachment size' do
      expect(subject).to have_no_selector('.hidden input[type=file]')
      expect(subject).to have_selector('input[type=file]:not(.hidden)')
      expect(subject).to have_content(/Taille maximale autorisée :\s+20 Mo/)
    end
  end

  context 'when there is a template' do
    before do
      component.with_template { "the template to render" }
    end

    it 'renders the template' do
      expect(subject).to have_text("the template to render")
    end
  end

  context 'when there is an attachment' do
    before do
      attach_to_champ(attached_file, champ)
    end

    it 'renders the filenames' do
      expect(subject).to have_content(attached_file.attachments[0].filename.to_s)
      expect(subject).to have_content(attached_file.attachments[1].filename.to_s)
    end

    it 'shows the Delete button by default' do
      expect(subject).to have_button(title: "Supprimer le fichier #{attached_file.attachments[0].filename}")
      expect(subject).to have_button(title: "Supprimer le fichier #{attached_file.attachments[1].filename}")
    end

    it 'renders a form field for uploading a new file' do
      expect(subject).to have_selector('input[type=file]:not(.hidden)')
    end

    it 'does not renders max size anymore' do
      expect(subject).to have_no_content(/Taille maximale/)
    end
  end

  context 'when the user cannot destroy the attachment' do
    let(:kwargs) { { user_can_destroy: false } }

    it 'hides the Delete button' do
      expect(subject).to have_no_link(title: "Supprimer le fichier #{attached_file.attachments[0].filename}")
    end

    it 'still renders the filename' do
      expect(subject).to have_content(attached_file.attachments[0].filename.to_s)
    end
  end

  context 'max attachments' do
    let(:kwargs) { { max: 1 } }

    it 'renders a disabled input file where max attachments has been reached' do
      expect(subject).to have_selector('input[type=file][disabled]')
    end
  end

  context 'attachment process in progress' do
    let(:created_at) { 1.second.ago }

    before do
      attached_file.attachments[0].blob.update(virus_scan_result: ActiveStorage::VirusScanner::PENDING)
      attached_file.attachments[0].update!(created_at:)
    end

    it 'setup polling' do
      expect(subject).to have_selector('[data-controller=turbo-poll]')
    end
  end

  def attach_to_champ(attached_file, champ)
    attached_file.attach(
      io: StringIO.new("x" * 2),
      filename: "me.jpg",
      content_type: "image/png",
      metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
    )
    champ.save!
  end
end
