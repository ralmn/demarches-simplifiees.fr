# frozen_string_literal: true

describe Champs::DropDownListChamp do
  let(:types_de_champ_public) { [{ type: :drop_down_list, drop_down_other: other }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champs.first.tap { _1.update(value:, other:) } }
  let(:value) { nil }
  let(:other) { nil }

  describe 'validations' do
    describe 'inclusion' do
      subject { champ.validate(:champs_public_value) }

      context 'when the other value is accepted' do
        let(:other) { true }

        context 'when the value is blank' do
          let(:value) { '' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is included in the option list' do
          let(:value) { 'val1' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is not included in the option list' do
          let(:value) { 'something else' }

          it { is_expected.to be_truthy }
        end
      end

      context 'when the other value is not accepted' do
        let(:other) { false }

        context 'when the value is blank' do
          let(:value) { '' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is included in the option list' do
          let(:value) { 'val1' }

          it { is_expected.to be_truthy }
        end

        context 'when the value is not included in the option list' do
          let(:value) { 'something else' }

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe '#drop_down_other?' do
    context 'when drop_down_other is nil' do
      it do
        champ.type_de_champ.drop_down_other = nil
        expect(champ.drop_down_other?).to be false

        champ.type_de_champ.drop_down_other = "0"
        expect(champ.drop_down_other?).to be false

        champ.type_de_champ.drop_down_other = false
        expect(champ.drop_down_other?).to be false

        champ.type_de_champ.drop_down_other = "1"
        expect(champ.drop_down_other?).to be true

        champ.type_de_champ.drop_down_other = true
        expect(champ.drop_down_other?).to be true
      end
    end
  end
end
