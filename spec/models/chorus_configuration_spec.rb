describe ChorusConfiguration do
  subject { create(:procedure) }
  it { is_expected.to be_valid }

  context 'empty' do
    subject { create(:procedure, chorus: {}) }
    it { is_expected.to be_valid }
  end

  context 'partially filled chorus_configuration' do
    subject { create(:procedure, chorus: { 'centre_de_cout' => '1' }) }
    it { is_expected.to be_valid }
  end

  context 'fully filled chorus_configuration' do
    subject { create(:procedure, chorus: { 'centre_de_coup' => {}, 'domaine_fonctionnel' => {}, 'referentiel_de_programmation' => {} }) }
    it { is_expected.to be_valid }
  end

  describe 'ChorusConfiguration' do
    it 'works without args' do
      expect { ChorusConfiguration.new }.not_to raise_error
    end

    it 'works with args' do
      expect { ChorusConfiguration.new({}) }.not_to raise_error
    end

    it 'works with existing args' do
      expect do
        cc = ChorusConfiguration.new()
        cc.assign_attributes(centre_de_coup: {}, domaine_fonctionnel: {}, referentiel_de_programmation: {})
      end.not_to raise_error
    end
  end
end
