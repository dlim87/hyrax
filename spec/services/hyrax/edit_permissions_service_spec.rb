RSpec.describe Hyrax::EditPermissionsService do
  let(:my_user) { create(:user) }
  let(:ability) { Ability.new(my_user) }
  # build users for testing
  let(:mgr1) { build(:user) }
  let(:mgr2) { build(:user) }
  let(:mgr3) { build(:user) }
  let(:mgr4) { build(:user) }
  let(:mgr5) { build(:user) }
  let(:vw1) { build(:user) }
  let(:vw2) { build(:user) }
  let(:vw3) { build(:user) }
  let(:vw4) { build(:user) }
  let(:coll_creator) { build(:user) }

  # build collections for testing
  # my_user has no manage rights to admin_set
  let(:admin_set) do
    build(:adminset_lw,
      id: 'default_admin_set',
      user: coll_creator,
      with_permission_template: { manage_users: [mgr1], view_users: [vw1] })
  end
  # my_user is creator, and therefore has manage rights to this collection
  let(:sharable_coll1) do
    build(:collection_lw,
      id: 'sharable_coll1',
      user: my_user,
      collection_type_settings: [:sharable],
      with_permission_template: { manage_users: [mgr2], view_users: [vw2] })
  end
  # my_user has no manage rights to this collection
  let(:sharable_coll2) do
    build(:collection_lw,
      id: 'sharable_coll2',
      user: coll_creator,
      collection_type_settings: [:sharable],
      with_permission_template: { manage_users: [mgr3], view_users: [vw3] })
  end
  # non-sharable collections do not impact the permissions of the works
  let(:nonsharable_collection) do
    build(:collection_lw,
      id: 'nonsharable_coll',
      user: coll_creator,
      collection_type_settings: [:not_sharable],
      with_permission_template: { manage_users: [mgr4], view_users: [vw4] })
  end

  # @note: using multiple collections only in order to test the complex situations
  # all at once. Permissions are also added onto the work here because multi-
  # membership at the time of creation prevents sharing permissions to the work
  # build work for testing:
  let(:generic_work) do
    build(:generic_work,
      user: my_user,
      edit_users: [mgr1, mgr2, mgr3, mgr4, mgr5],
      read_users: [vw1, vw2, vw3, vw4],
      visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE,
      member_of_collections: [sharable_coll1, sharable_coll2, nonsharable_collection],
      admin_set: admin_set)
  end

  let(:work_permission_service) { described_class.new(object: generic_work, ability: ability) }

  before do
    allow(ActiveFedora::Base).to receive(:find).with(admin_set.id).and_return(admin_set)
    allow(ActiveFedora::Base).to receive(:find).with(sharable_coll1.id).and_return(sharable_coll1)
    allow(ActiveFedora::Base).to receive(:find).with(sharable_coll2.id).and_return(sharable_coll2)
    allow(ActiveFedora::Base).to receive(:find).with(nonsharable_collection.id).and_return(nonsharable_collection)
  end

  describe '#initialize' do
    let(:subject) { work_permission_service }

    it 'responds to #depositor and #unauthorized_collection_managers' do
      expect(subject).to respond_to(:depositor)
      expect(subject).to respond_to(:unauthorized_collection_managers)
      expect(subject.depositor).to eq(my_user.user_key)
    end
  end

  describe '#cannot_edit_permissions?' do
    let(:subject) { work_permission_service }

    context 'validating which collection managers user may manage' do
      it 'allows user to change managers from authorized collection' do
        expect(subject.unauthorized_collection_managers).not_to include(id: sharable_coll1.id, name: mgr2.user_key)
        expect(subject.cannot_edit_permissions?(Hash[name: mgr2.name, type: 'person', access: 'edit'])).to eq false
      end

      it 'restricts user from changing managers from unauthorized collections' do
        expect(subject.unauthorized_collection_managers).to contain_exactly({ id: sharable_coll2.id, name: mgr3.user_key }, { id: sharable_coll2.id, name: coll_creator.user_key }, { id: admin_set.id, name: mgr1.user_key }, { id: admin_set.id, name: coll_creator.user_key })
        expect(subject.cannot_edit_permissions?(Hash[name: mgr1.name, type: 'person', access: 'edit'])).to eq true
        expect(subject.cannot_edit_permissions?(Hash[name: mgr3.name, type: 'person', access: 'edit'])).to eq true
      end

      it 'allows user to change managers not from sharable collections' do
        expect(subject.unauthorized_collection_managers).not_to include(id: nonsharable_collection.id, name: mgr4.user_key)
        expect(subject.cannot_edit_permissions?(Hash[name: mgr4.name, type: 'person', access: 'edit'])).to eq false
      end

      it 'allows user to change non-manager permissions from non-permitted collection' do
        expect(subject.unauthorized_collection_managers).not_to include(id: sharable_coll2.id, name: vw3.user_key)
        expect(subject.cannot_edit_permissions?(Hash[name: vw3.name, type: 'person', access: 'read'])).to eq false
      end

      it 'allows user to change non-collection manager permissions' do
        expect(subject.cannot_edit_permissions?(Hash[name: mgr5.name, type: 'person', access: 'edit'])).to eq false
      end
    end
  end

  describe '#excluded_permission?' do
    let(:subject) { work_permission_service.excluded_permission?(permission_hash) }

    context 'for an excluded permission' do
      let(:permission_hash) { Hash[name: my_user.name, type: 'person', access: 'edit'] }

      it 'returns true' do
        expect(subject).to eq true
      end
    end

    context 'for an allowed permission' do
      let(:permission_hash) { Hash[name: mgr1.name, type: 'person', access: 'edit'] }

      it 'returns false' do
        expect(subject).to eq false
      end
    end
  end
end
