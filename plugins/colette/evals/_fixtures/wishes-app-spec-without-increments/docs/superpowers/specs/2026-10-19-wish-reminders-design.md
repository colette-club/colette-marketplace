# Wish reminders — design

## Why

Members forget the wishes they posted, so activities that would match them go unfilled.

## What

- Weekly reminders of a member's open wishes, by email, push notification and in-app message.
- Per-member settings for the channels and the day of the week.
- An admin view of how many reminders went out per channel.
- GraphQL fields for the settings, in the mobile app and the web front.
- A scheduled Oban job that sends them.

## Non-goals

Reminders for anything other than wishes; SMS.
