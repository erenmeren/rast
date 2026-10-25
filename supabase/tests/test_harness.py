import unittest

import harness


class HarnessTests(unittest.TestCase):
    def test_migrations_apply_and_postgis_is_available(self):
        rows = harness.db().run(
            "select postgis_full_version() like 'POSTGIS=%', (select count(*) from pg_namespace where nspname = 'app');"
        )
        self.assertEqual(rows, [["t", "1"]])

    def test_as_user_sets_auth_uid(self):
        rows = harness.db().run(harness.as_user(harness.uuid(1), "select auth.uid();"))
        self.assertEqual(rows, [[harness.uuid(1)]])

    def test_sql_errors_raise(self):
        with self.assertRaises(harness.SqlError):
            harness.db().run("select 1/0;")


if __name__ == "__main__":
    unittest.main()
