RSpec.describe Hyrax::EditPermissionsService do
  let(:ability) { double(Ability) }
  let(:depositing_user) { build(:user) }
  let(:mgr1) { build(:user) }
  let(:mgr2) { build(:user) }
  let(:vw1) { build(:user) }
  let(:user) { build(:user) }
  let(:admin) { build(:admin) }

  # build collections for testing
  let(:admin_set) { build(:adminset_lw, with_permission_template: { manage_users: [mgr1], view_users: [vw1] }) }
  let(:sharable_collection) { build(:collection_lw, collection_type_settings: [:sharable], title: ["A Sharable Collection"], with_permission_template: { manage_users: [mgr2], view_users: [vw1] }) }
  let(:nonsharable_collection) { build(:collection_lw, collection_type_settings: [:not_sharable], title: ["A Non-Sharable Collection"], with_permission_template: { manage_users: [mgr2], view_users: [vw1] }) }

  # build works for testing
  let(:private) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }
  let(:generic_work) { build(:generic_work, visibility: private, user: depositing_user, member_of_collections: [sharable_collection, nonsharable_collection, admin_set]) }

  let(:work_permission_service) { described_class.new(object: generic_work, ability: ability) }

  # describe '#initialize' do
  #   context 'when object generic_work' do
  #     let(:subject) { work_permission_service }
  #
  #     before do
  #     end
  #
  #     it 'responds to depositor and unauthorized_collection_managers' do
  #       expect(subject.deposit).to equal(depositing_user)
  #       expect(subject.unauthorized_collection_managers).to equal([])
  #     end
  #   end
  # end
  #
  # describe '#cannot_edit_permissions?' do
  #   context 'for an unauthorized user' do
  #     # let(:permission_hash) { :name=>"lrobins5@nd.edu", :type=>"person", :access=>"edit" }
  #
  #     it 'returns true' do
  #
  #     end
  #   end
  #
  #   context 'for an authorized user' do
  #     let(:permission_hash) {}
  #
  #     it 'returns false' do
  #
  #     end
  #   end
  # end

  describe '#excluded_permission?' do
    context 'for an excluded permission' do
      let(:permission_hash) { Hash.new(name: depositing_user.name, type: "person", access: "edit") }
      let(:subject) { work_permission_service.excluded_permission?(permission_hash) }

      before do
        allow(ActiveFedora::Base).to receive(:find).with(sharable_collection.id).and_return(sharable_collection)
        allow(ActiveFedora::Base).to receive(:find).with(nonsharable_collection.id).and_return(nonsharable_collection)
        allow(ActiveFedora::Base).to receive(:find).with(admin_set.id).and_return(admin_set)
      end

      it 'returns true' do
        expect(subject).to be_true
      end
    end

    context 'for an allowed permission' do
      let(:permission_hash) { Hash.new(name: mgr1.name, type: "person", access: "edit") }
      let(:subject) { work_permission_service.excluded_permission?(permission_hash) }

      it 'returns false' do
        expect(subject).to be_false
      end
    end
  end
end
