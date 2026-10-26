-- Replacing a photo: the new upload may sit in the slot as `uploading` while
-- the old one stays `ready`, so a rejected upload loses nothing. The
-- finalize function retires the old ready row when it marks the new one.
drop index if exists photo_live_slot;
create unique index photo_ready_slot on photo (account_id, slot) where state = 'ready';
create unique index photo_uploading_slot on photo (account_id, slot) where state = 'uploading';
