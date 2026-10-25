import unittest

from harness import db, member, sample, uuid


class RetentionTests(unittest.TestCase):
    def test_samples_older_than_24h_are_purged(self):
        sql = (member(1) + sample(1, 1, sample_id=uuid(900)) + sample(1, 2, sample_id=uuid(901))
               + "update location_sample set received_at = now() - interval '25 hours' where id = '%s';" % uuid(900))
        rows = db().run(sql + "select app.purge_location_samples(); select id from location_sample;")
        self.assertEqual(rows[-2:], [["1"], [uuid(901)]])

    def test_void_encounters_older_than_30_days_are_purged(self):
        sql = member(1) + member(2) + sample(1, 1) + sample(2, 1, distance=5) + "update encounter set state = 'void', created_at = now() - interval '31 days';"
        self.assertEqual(db().run(sql + "select app.purge_void_encounters(); select count(*) from encounter;")[-2:], [["1"], ["0"]])
        keep = member(1) + member(2) + sample(1, 1) + sample(2, 1, distance=5) + "update encounter set state = 'void';"
        self.assertEqual(db().run(keep + "select app.purge_void_encounters();")[-1], ["0"])

    def test_cron_schedule_is_skipped_without_pg_cron(self):
        self.assertEqual(db().run("select count(*) from pg_extension where extname = 'pg_cron';"), [["0"]])


if __name__ == "__main__":
    unittest.main()
