# == Schema Information
# Schema version: 19
#
# Table name: posts
#
#  id                       :integer         not null, primary key
#  blog_id                  :integer
#  topic_id                 :integer
#  person_id                :integer
#  title                    :string(255)
#  body                     :text
#  blog_post_comments_count :integer         default(0), not null
#  type                     :string(255)
#  created_at               :datetime
#  updated_at               :datetime
#

class ForumPost < Post
  acts_as_ferret :fields => [ :title, :body ] if search?

  belongs_to :topic,  :counter_cache => true
  belongs_to :person, :counter_cache => true

  validates_presence_of :body, :person
  validates_length_of :body, :maximum => MAX_TEXT_LENGTH

  after_create :log_activity

  class << self
    def search(options = {})
      query = options[:q]
      return [] if query.blank?
      # TODO: change the limit (probably when switching to Sphinx).
      find_by_contents(query, :limit => :all,
                              :conditions => ['forum_id = :forum_id', options])
    end
  end

  private

    def log_activity
      add_activities(:item => self, :person => person)
    end
end
