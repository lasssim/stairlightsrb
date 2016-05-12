Feature: Single Color

  Background:
    Given there is a canvas of 4x50 pixels

  @wip
  Scenario: Red Color 
    When a User selects the color red
    Then all pixels should be set to red
