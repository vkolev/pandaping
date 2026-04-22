//
//  ChannelUserTests.swift
//  PandaPingTests
//
//  Created by Vladimir Kolev on 22.04.26.
//

import Testing
@testable import PandaPing

@Suite("Channel User")
struct ChannelUserTests {

    @Test("Parses operator prefix @")
    func operatorPrefix() {
        let user = ChannelUser(prefixedNick: "@alice")

        #expect(user.nickname == "alice")
        #expect(user.modePrefix == "@")
        #expect(user.displayName == "@alice")
    }

    @Test("Parses voice prefix +")
    func voicePrefix() {
        let user = ChannelUser(prefixedNick: "+bob")

        #expect(user.nickname == "bob")
        #expect(user.modePrefix == "+")
    }

    @Test("Parses halfop prefix %")
    func halfopPrefix() {
        let user = ChannelUser(prefixedNick: "%charlie")

        #expect(user.nickname == "charlie")
        #expect(user.modePrefix == "%")
    }

    @Test("No prefix for regular user")
    func noPrefix() {
        let user = ChannelUser(prefixedNick: "dave")

        #expect(user.nickname == "dave")
        #expect(user.modePrefix == nil)
        #expect(user.displayName == "dave")
    }

    @Test("Init with nickname only has no prefix")
    func nicknameInit() {
        let user = ChannelUser(nickname: "eve")

        #expect(user.nickname == "eve")
        #expect(user.modePrefix == nil)
    }

    @Test("Sort order: ops < halfops < voice < regular")
    func sortOrder() {
        let op = ChannelUser(prefixedNick: "@alice")
        let halfop = ChannelUser(prefixedNick: "%bob")
        let voice = ChannelUser(prefixedNick: "+charlie")
        let regular = ChannelUser(prefixedNick: "dave")

        #expect(op.sortOrder < halfop.sortOrder)
        #expect(halfop.sortOrder < voice.sortOrder)
        #expect(voice.sortOrder < regular.sortOrder)
    }

    @Test("Equality based on nickname")
    func equality() {
        let a = ChannelUser(nickname: "alice")
        let b = ChannelUser(prefixedNick: "@alice")

        // Different modePrefix means not equal
        #expect(a != b)

        let c = ChannelUser(nickname: "alice")
        #expect(a == c)
    }
}
