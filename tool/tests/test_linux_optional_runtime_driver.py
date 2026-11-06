"""Outgoing-message oracle regressions; no GUI or application is launched."""
import importlib.util
from pathlib import Path
import unittest

TOOL = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('optional_runtime_driver', TOOL / 'linux_optional_runtime_driver.py')
driver = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(driver)
EXPECTED = 'Optional outgoing proof'
COMPOSER_TOP = 1284


def state(contents, sent=1):
    return {'sent': sent, 'messages': [
        {'id': f'own-{index}', 'senderId': 'optional-human', 'content': value}
        for index, value in enumerate(contents)]}


class OutgoingOracleTests(unittest.TestCase):
    def desktop(self, rows):
        value = driver.Desktop(Path('/unused'), {})
        value.snapshot = lambda label: (Path(label + '.png'), rows)
        return value

    def test_pending_request_is_not_success(self):
        self.assertIsNone(driver.saved_outgoing(state([], sent=0), EXPECTED))

    def test_exact_single_saved_body_passes(self):
        row = driver.saved_outgoing(state([EXPECTED]), EXPECTED)
        self.assertEqual(row['content'], EXPECTED)

    def test_original_two_truncated_http_bodies_are_rejected(self):
        # runtime-matrix-core01 / 01-ubuntu-missing-webkit and
        # 02-ubuntu-missing-mpv core-service-readback.json respectively.
        for partial in ('Optional outgoing p', 'Optional'):
            with self.subTest(partial=partial):
                with self.assertRaisesRegex(AssertionError, 'Outgoing HTTP body differs'):
                    driver.saved_outgoing(state([partial]), EXPECTED)

    def test_duplicate_own_rows_or_post_count_are_rejected(self):
        for value in (state([EXPECTED, EXPECTED]), state([EXPECTED], sent=2)):
            with self.subTest(value=value):
                with self.assertRaises(AssertionError):
                    driver.saved_outgoing(value, EXPECTED)

    def test_peer_copy_cannot_replace_missing_own_message(self):
        value = {'sent': 1, 'messages': [
            {'id': 'peer', 'senderId': 'optional-peer', 'content': EXPECTED}]}
        with self.assertRaises(AssertionError):
            driver.saved_outgoing(value, EXPECTED)

    def test_original_full_composer_cannot_be_sent_bubble(self):
        # Exact text/boxes in both original 013-sent-visible.json failures.
        # The old unbounded matcher accepted this unsent composer text.
        for partial in ('Optional outgoing p', 'Optional'):
            rows = [{'text': partial, 'box': [740, 1128, 1044, 1156]},
                    {'text': EXPECTED, 'box': [677, 1284, 1047, 1312]}]
            with self.subTest(partial=partial):
                _, old_match = self.desktop(rows).find(EXPECTED, 'old', timeout=0)
                self.assertEqual(old_match['box'][1], COMPOSER_TOP)
                with self.assertRaisesRegex(AssertionError, 'Visible text not found'):
                    self.desktop(rows).find(EXPECTED, 'sent', timeout=0,
                                            max_y=COMPOSER_TOP - 1)

    def test_actual_bubble_above_composer_is_selected(self):
        bubble = {'text': EXPECTED, 'box': [740, 1128, 1110, 1156]}
        composer = {'text': EXPECTED, 'box': [677, 1284, 1047, 1312]}
        _, match = self.desktop([composer, bubble]).find(
            EXPECTED, 'sent', timeout=0, max_y=COMPOSER_TOP - 1)
        self.assertEqual(match, bubble)

    def test_pre_submit_wait_requires_text_in_composer_region(self):
        bubble = {'text': EXPECTED, 'box': [740, 1128, 1110, 1156]}
        composer = {'text': EXPECTED, 'box': [677, 1284, 1047, 1312]}
        with self.assertRaises(AssertionError):
            self.desktop([bubble]).find(EXPECTED, 'ready', timeout=0,
                                        min_y=COMPOSER_TOP - 10)
        _, match = self.desktop([bubble, composer]).find(
            EXPECTED, 'ready', timeout=0, min_y=COMPOSER_TOP - 10)
        self.assertEqual(match, composer)

    def test_placeholder_in_another_region_does_not_prove_composer_cleared(self):
        other = {'text': 'Message #general', 'box': [50, 100, 320, 128]}
        placeholder = {'text': 'Message #general', 'box': [678, 1284, 954, 1312]}
        with self.assertRaises(AssertionError):
            self.desktop([other]).find('Message #general', 'cleared', timeout=0,
                                       min_y=COMPOSER_TOP - 10)
        _, match = self.desktop([other, placeholder]).find(
            'Message #general', 'cleared', timeout=0, min_y=COMPOSER_TOP - 10)
        self.assertEqual(match, placeholder)


if __name__ == '__main__':
    unittest.main()
