import unittest

from harness import SqlError, as_user, db, member, uuid

PAIR = "insert into pair(id, a, b, matched_at) values ('%s', '%s', '%s', now());" % (uuid(50), uuid(1), uuid(2))
ENC = "insert into encounter(id, pair_id, encountered_at, rule_version, release_at, state) values (gen_random_uuid(), '%s', now(), 1, now(), '%s');"


class PairTableTests(unittest.TestCase):
    def test_pair_is_canonical_and_unique(self):
        with self.assertRaisesRegex(SqlError, "pair_canonical"):
            db().run(member(1) + member(2) + "insert into pair(id, a, b) values (gen_random_uuid(), '%s', '%s');" % (uuid(2), uuid(1)))
        with self.assertRaisesRegex(SqlError, "pair_unique"):
            db().run(member(1) + member(2) + ("insert into pair(id, a, b) values (gen_random_uuid(), '%s', '%s');" % (uuid(1), uuid(2))) * 2)

    def test_one_live_encounter_per_pair(self):
        base = member(1) + member(2) + PAIR
        with self.assertRaisesRegex(SqlError, "encounter_live_pair"):
            db().run(base + ENC % (uuid(50), 'pending') + ENC % (uuid(50), 'released'))
        rows = db().run(base + ENC % (uuid(50), 'void') + ENC % (uuid(50), 'pending') + "select count(*) from encounter;")
        self.assertEqual(rows, [["2"]])

    def test_encounter_times_are_not_selectable_by_clients(self):
        base = member(1) + member(2) + PAIR
        self.assertEqual(db().run(base + as_user(uuid(1), "select count(*) from encounter;")), [["0"]])
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(base + as_user(uuid(1), "select release_at from encounter;"))
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(base + as_user(uuid(1), "select encountered_at from encounter;"))

    def test_pair_rows_visible_only_to_members(self):
        base = member(1) + member(2) + member(3) + PAIR
        self.assertEqual(db().run(base + as_user(uuid(2), "select count(*) from pair;")), [["1"]])
        self.assertEqual(db().run(base + as_user(uuid(3), "select count(*) from pair;")), [["0"]])

    def test_clients_cannot_write_pair_tables(self):
        for stmt in ["insert into pair(id, a, b) values (gen_random_uuid(), '%s', '%s')" % (uuid(1), uuid(2)),
                     "insert into block(blocker, blocked) values ('%s', '%s')" % (uuid(1), uuid(2))]:
            with self.subTest(stmt=stmt), self.assertRaisesRegex(SqlError, "permission denied"):
                db().run(member(1) + member(2) + as_user(uuid(1), stmt + ";"))

    def test_params_single_row_seed(self):
        self.assertEqual(db().run("select radius_m, max_skew_s, max_sample_age_s, max_future_s, max_accuracy_m, rule_version from encounter_params;"),
                         [["20", "60", "86400", "60", "50", "1"]])
        with self.assertRaisesRegex(SqlError, "encounter_params_id_check"):
            db().run("insert into encounter_params(id, radius_m, max_skew_s, max_sample_age_s, max_future_s, max_accuracy_m, rule_version) values (false, 1, 1, 1, 1, 1, 1);")

    def test_message_body_length(self):
        base = member(1) + member(2) + PAIR
        for body in ["''", "repeat('x', 2001)"]:
            with self.subTest(body=body), self.assertRaisesRegex(SqlError, "message_body_check"):
                db().run(base + "insert into message(id, pair_id, sender, client_op_id, seq, body) values (gen_random_uuid(), '%s', '%s', gen_random_uuid(), 1, %s);" % (uuid(50), uuid(1), body))


if __name__ == "__main__":
    unittest.main()
