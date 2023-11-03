class ExpiredUsersDeletionService
  include MailRateLimitable

  RETENTION_AFTER_NOTICE_IN_WEEK = 2
  EXPIRABLE_AFTER_IN_YEAR = 2

  def process_expired
    [expiring_users_without_dossiers, expiring_users_with_dossiers].map do |expiring_segment|
      delete_expired_users(expiring_segment)
      send_inactive_close_to_expiration_notice(expiring_segment)
    end
  end

  def send_inactive_close_to_expiration_notice(users)
    to_notify_only(users).in_batches do |batch|
      batch.each do |user|
        safe_send_email(UserMailer.notify_inactive_close_to_deletion(user))
      end
      batch.update_all(inactive_close_to_expiration_notice_sent_at: Time.zone.now.utc)
    end
  end

  def delete_expired_users(users)
    to_delete_only(users).find_each do |user|
      user.delete_and_keep_track_dossiers_also_delete_user(nil)
    end
  end

  # rubocop:disable DS/Unscoped
  def expiring_users_with_dossiers
    User.unscoped # avoid default_scope eager_loading :export, :instructeur, :administrateur
      .joins(:dossiers)
      .having('MAX(dossiers.created_at) < ?', EXPIRABLE_AFTER_IN_YEAR.years.ago)
      .group('users.id')
  end

  def expiring_users_without_dossiers
    User.unscoped
      .where
      .missing(:dossiers)
      .where(last_sign_in_at: ..EXPIRABLE_AFTER_IN_YEAR.years.ago)
  end
  # rubocop:enable DS/Unscoped

  def to_notify_only(users)
    users.where(inactive_close_to_expiration_notice_sent_at: nil)
  end

  def to_delete_only(users)
    users.where.not(inactive_close_to_expiration_notice_sent_at: RETENTION_AFTER_NOTICE_IN_WEEK.weeks.ago..)
  end
end
