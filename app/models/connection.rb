# == Schema Information
# Schema version: 19
#
# Table name: connections
#
#  id          :integer         not null, primary key
#  person_id   :integer
#  contact_id  :integer
#  status      :integer
#  accepted_at :datetime
#  created_at  :datetime
#  updated_at  :datetime
#

class Connection < ActiveRecord::Base
  extend ActivityLogger
  extend PreferencesHelper

  belongs_to :person
  belongs_to :contact, :class_name => "Person", :foreign_key => "contact_id"
  has_many :activities, :foreign_key => "item_id", :dependent => :destroy
  validates_presence_of :person_id, :contact_id

  # Status codes.
  ACCEPTED  = 0
  REQUESTED = 1
  PENDING   = 2

  # Accept a connection request (instance method).
  # Each connection is really two rows, so delegate this method
  # to Connection.accept to wrap the whole thing in a transaction.
  def accept
    Connection.accept(person_id, contact_id)
  end

  def breakup
    Connection.breakup(person_id, contact_id)
  end

  class << self

    # Return true if the persons are (possibly pending) connections.
    def exists?(person, contact)
      not conn(person, contact).nil?
    end

    alias exist? exists?

    # Make a pending connection request.
    def request(person, contact, mail = global_prefs.email_notifications)
      if person == contact or Connection.exists?(person, contact)
        nil
      else
        transaction do
          create(:person => person, :contact => contact, :status => PENDING)
          create(:person => contact, :contact => person, :status => REQUESTED)
        end
        connection = conn(person, contact)
        PersonMailer.deliver_connection_request(connection) if mail
        connection
      end
    end

    # Accept a connection request.
    def accept(person, contact)
      transaction do
        accepted_at = Time.now
        accept_one_side(person, contact, accepted_at)
        accept_one_side(contact, person, accepted_at)
      end
      log_activity(conn(person, contact))
    end

    def connect(person, contact, mail = global_prefs.email_notifications)
      transaction do
        request(person, contact, mail)
        accept(person, contact)
      end
    end

    # Delete a connection or cancel a pending request.
    def breakup(person, contact)
      transaction do
        destroy(conn(person, contact))
        destroy(conn(contact, person))
      end
    end

    # Return a connection based on the person and contact.
    def conn(person, contact)
      find_by_person_id_and_contact_id(person, contact)
    end

    def accepted?(person, contact)
      conn(person, contact).status == ACCEPTED
    end

    def connected?(person, contact)
      exist?(person, contact) and accepted?(person, contact)
    end
  end

  private

  class << self
    # Update the db with one side of an accepted connection request.
    def accept_one_side(person, contact, accepted_at)
      conn = conn(person, contact)
      conn.update_attributes!(:status => ACCEPTED,
                              :accepted_at => accepted_at)
    end

    def log_activity(conn)
      activity = Activity.create!(:item => conn, :person => conn.person)
      add_activities(:activity => activity, :person => conn.person)
      add_activities(:activity => activity, :person => conn.contact)
    end
  end
end
