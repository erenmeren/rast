import unittest

from harness import SqlError, as_user, db, member, uuid
from test_discovery import call, like, released_group


def obj(bucket, name, owner=None):
    return "insert into storage.objects(bucket_id, name, owner_id) values ('%s', '%s', %s);" % (bucket, name, "'%s'" % owner if owner else "null")


class MediaTests(unittest.TestCase):
    def test_buckets(self):
        rows = db().run("select id, public, file_size_limit, allowed_mime_types from storage.buckets order by id;")
        self.assertEqual(rows[-2:], [["photos", "f", "5242880", "{image/jpeg,image/png}"], ["previews", "f", "", ""]])

    def test_photo_owner_parses_or_returns_null(self):
        rows = db().run("select app.photo_owner('%s/0.jpg'), app.photo_owner(upper('%s')||'/0.jpg'), app.photo_owner('junk/0.jpg'), app.photo_owner('0.jpg'), app.photo_owner('');" % (uuid(1), uuid(1)))
        self.assertEqual(rows[-1], [uuid(1), uuid(1), "", "", ""])

    def test_owner_can_write_and_read_own_objects(self):
        sql = member(1) + as_user(uuid(1), obj("photos", uuid(1) + "/0.jpg") + "select count(*) from storage.objects;" + "delete from storage.objects; select count(*) from storage.objects;")
        self.assertEqual(db().run(sql)[-2:], [["1"], ["0"]])

    def test_cannot_write_under_another_folder_or_previews(self):
        for name, bucket in [(uuid(2) + "/0.jpg", "photos"), ("junk/0.jpg", "photos"), ("x.jpg", "previews")]:
            with self.subTest(name=name, bucket=bucket), self.assertRaisesRegex(SqlError, "row-level security"):
                db().run(member(1) + member(2) + as_user(uuid(1), obj(bucket, name)))

    def test_read_follows_can_view_photos(self):
        base = released_group(1, 2, 3) + obj("photos", uuid(2) + "/0.jpg", uuid(2)) + obj("previews", "p.jpg")
        self.assertEqual(db().run(base + as_user(uuid(1), "select count(*) from storage.objects;"))[-1], ["1"])
        self.assertEqual(db().run(base + member(9) + as_user(uuid(9), "select count(*) from storage.objects;"))[-1], ["0"])
        self.assertEqual(db().run(base + call(1, "block_account('%s')" % uuid(2)) + as_user(uuid(1), "select count(*) from storage.objects;"))[-1], ["0"])
        self.assertEqual(db().run(released_group(1, 2, delay=2) + obj("photos", uuid(2) + "/0.jpg", uuid(2)) + as_user(uuid(1), "select count(*) from storage.objects;"))[-1], ["0"])

    def test_storage_path_must_start_with_own_account(self):
        with self.assertRaisesRegex(SqlError, "photo_path_own_folder"):
            db().run(member(1) + member(2) + "insert into photo(account_id, slot, storage_path, state) values ('%s', 0, '%s/x.jpg', 'uploading');" % (uuid(1), uuid(2)))

    def test_ready_is_server_only(self):
        sql = member(1, photos=0) + "insert into photo(id, account_id, slot, storage_path) values ('%s', '%s', 0, '%s/0.jpg');" % (uuid(500), uuid(1), uuid(1))
        with self.assertRaisesRegex(SqlError, "photo_ready_is_server_only"):
            db().run(sql + as_user(uuid(1), "update photo set state = 'ready' where id = '%s';" % uuid(500)))
        self.assertEqual(db().run(sql + as_user(uuid(1), "update photo set state = 'removed' where id = '%s';" % uuid(500)) + "select state from photo;")[-1], ["removed"])
        self.assertEqual(db().run(sql + "update photo set state = 'ready' where id = '%s'; select state from photo;" % uuid(500))[-1], ["ready"])

    def test_resolve_like_preview(self):
        # the token is read as postgres: clients never see like_preview
        base = released_group(1, 2, 3) + like(2, 1, 700) + call(1, "likes_you()") + "create temp table tok as select token, (select id from photo where account_id = '%s' and slot = 0) as photo from like_preview where viewer = '%s'; grant select on tok to authenticated;" % (uuid(2), uuid(1))
        token = "(select token from tok)"
        photo = "(select photo from tok)"
        self.assertEqual(db().run(base + call(1, "resolve_like_preview(%s) = %s" % (token, photo)))[-1], ["t"])
        self.assertEqual(db().run(base + call(3, "resolve_like_preview(%s)" % token))[-1], [""])
        self.assertEqual(db().run(base + "update like_preview set expires_at = now() - interval '1 second';" + call(1, "resolve_like_preview(%s)" % token))[-1], [""])
        self.assertEqual(db().run(base + call(1, "block_account('%s')" % uuid(2)) + call(1, "resolve_like_preview(%s)" % token))[-1], [""])

    def test_privileges(self):
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run("set local role anon; select public.resolve_like_preview(gen_random_uuid());")
        self.assertEqual(db().run(as_user(uuid(1), "select app.photo_owner('x');"))[-1], [""])


if __name__ == "__main__":
    unittest.main()
