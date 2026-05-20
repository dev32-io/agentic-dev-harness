package io.dev32.sample

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CounterScreenRobolectricTest {

    @get:Rule val composeTestRule = createComposeRule()

    @Test
    fun increments_on_click() {
        var count = 0
        composeTestRule.setContent {
            MaterialTheme {
                Surface {
                    CounterContent(count = count, onIncrement = { count++ })
                }
            }
        }
        composeTestRule.onNodeWithTag("count").assertIsDisplayed()
        composeTestRule.onNodeWithTag("increment").performClick()
    }
}
