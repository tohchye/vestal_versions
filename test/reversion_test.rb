require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class ReversionTest < Test::Unit::TestCase
  context 'A model reversion' do
    setup do
      @user, @attributes, @times = User.new, {}, {}
      names = ['Steve Richert', 'Stephen Richert', 'Stephen Jobs', 'Steve Jobs']
      time = names.size.hours.ago
      names.each do |name|
        @user.update_attribute(:name, name)
        @attributes[@user.version] = @user.attributes
        time += 1.hour
        if last_version = @user.versions.last
          last_version.update_attribute(:created_at, time)
        end
        @times[@user.version] = time
      end
      @user.reload.versions.reload
      @first_version, @last_version = @attributes.keys.min, @attributes.keys.max
    end

    should 'return the new version number' do
      new_version = @user.revert_to(@first_version)
      assert_equal @first_version, new_version
    end

    should 'change the version number when saved' do
      current_version = @user.version
      @user.revert_to!(@first_version)
      assert_not_equal current_version, @user.version
    end

    should 'do nothing for a invalid argument' do
      current_version = @user.version
      [nil, :bogus, 'bogus', (1..2)].each do |invalid|
        @user.revert_to(invalid)
        assert_equal current_version, @user.version
      end
    end

    should 'be able to target a version number' do
      @user.revert_to(1)
      assert_equal 1, @user.version
    end

    should 'be able to target a date and time' do
      @times.each do |version, time|
        @user.revert_to(time + 1.second)
        assert_equal version, @user.version
      end
    end

    should 'be able to target a version object' do
      @user.versions.each do |version|
        @user.revert_to(version)
        assert_equal version.number, @user.version
      end
    end

    should "correctly roll back the model's attributes" do
      timestamps = %w(created_at created_on updated_at updated_on)
      @attributes.each do |version, attributes|
        @user.revert_to!(version)
        assert_equal attributes.except(*timestamps), @user.attributes.except(*timestamps)
      end
    end

    should "store the reverted_from pointing to the previous version" do
      @user.revert_to!(1)
      assert_equal 1, @user.versions.last.reverted_from
    end

    should "not store the revereted_from for subsequent saves" do
      @user.revert_to!(1)
      @user.update_attributes(:name => 'Bill Gates')
      assert_equal nil, @user.versions.last.reverted_from
    end

    should "store the reverted_from pointing to the version it was reverted from when save is called later" do
      @user.revert_to(1)
      @user.name = "Reverted"
      @user.save
      assert_equal 1, @user.versions.last.reverted_from
    end

    should "not store the reverted_from for subsequent saves when the revert_to-save is called later" do
      @user.revert_to(1)
      @user.name = "Reverted"
      @user.save
      @user.update_attributes(:name => 'Bill Gates')
      assert_equal nil, @user.versions.last.reverted_from
    end

    should "clear the reverted_from if the model is reloaded after a revert_to without a save" do
      @user.revert_to(1)
      @user.reload
      @user.update_attributes(:name => 'Bill Gates')
      assert_equal nil, @user.versions.last.reverted_from
    end

    should "return all reverted versions excluding the last version" do
      @revisions = @user.revisions
      @revisions.each do |revision|
        @user.revert_to(revision.version)
        assert_equal revision.name, @user.name
      end
    end
  end
end
