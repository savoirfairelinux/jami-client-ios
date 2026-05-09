/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import XCTest
@testable import Ring

final class GroupAvatarRendererTests: XCTestCase {

    // MARK: - Helpers

    private func makeCandidate(name: String, role: String?, image: UIImage? = nil) -> GroupAvatarCandidate {
        GroupAvatarCandidate(member: GroupAvatarMember(image: image, name: name), role: role)
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    // MARK: - selectForDisplay: Empty & Edge Cases

    func testSelectForDisplay_EmptyCandidates() {
        let selection = GroupAvatarRenderer.selectForDisplay(from: [])
        XCTAssertTrue(selection.members.isEmpty)
        XCTAssertTrue(selection.selectedIndices.isEmpty)
        XCTAssertEqual(selection.overflowCount, 0)
    }

    func testSelectForDisplay_AllBannedReturnsEmpty() {
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.banned),
            makeCandidate(name: profileName2, role: MemberRoles.left)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertTrue(selection.members.isEmpty)
        XCTAssertEqual(selection.overflowCount, 0)
    }

    func testSelectForDisplay_NilRolePassesThrough() {
        let candidates = [
            makeCandidate(name: profileName1, role: nil),
            makeCandidate(name: profileName2, role: nil)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members.count, 2)
        XCTAssertEqual(selection.overflowCount, 0)
    }

    // MARK: - selectForDisplay: Role Filtering

    func testSelectForDisplay_FiltersBannedAndLeft() {
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: profileName2, role: MemberRoles.member),
            makeCandidate(name: profileName3, role: MemberRoles.banned),
            makeCandidate(name: profileName4, role: MemberRoles.left)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        let names = selection.members.map(\.name)
        XCTAssertTrue(names.contains(profileName1))
        XCTAssertTrue(names.contains(profileName2))
        XCTAssertFalse(names.contains(profileName3))
        XCTAssertFalse(names.contains(profileName4))
        XCTAssertEqual(selection.overflowCount, 0)
    }

    func testSelectForDisplay_IncludesInvited() {
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: profileName2, role: MemberRoles.invited)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members.count, 2)
        XCTAssertTrue(selection.members.map(\.name).contains(profileName2))
    }

    // MARK: - selectForDisplay: Admin First

    func testSelectForDisplay_AdminAlwaysFirst() {
        let candidates = [
            makeCandidate(name: profileName2, role: MemberRoles.member),
            makeCandidate(name: profileName3, role: MemberRoles.member),
            makeCandidate(name: profileName1, role: MemberRoles.admin)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members[0].name, profileName1)
    }

    // MARK: - selectForDisplay: Priority Sorting

    func testSelectForDisplay_PrioritizesImageOverName() {
        let image = createTestImage()
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: profileName2, role: MemberRoles.member),
            makeCandidate(name: profileName3, role: MemberRoles.member, image: image),
            makeCandidate(name: jamiId3, role: MemberRoles.member)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members.count, 2)
        XCTAssertEqual(selection.members[0].name, profileName1)
        XCTAssertEqual(selection.members[1].name, profileName3)
        XCTAssertEqual(selection.overflowCount, 2)
    }

    func testSelectForDisplay_HashNameGetsLowestPriority() {
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: jamiId2, role: MemberRoles.member),
            makeCandidate(name: registeredName1, role: MemberRoles.member),
            makeCandidate(name: jamiId3, role: MemberRoles.member)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members.count, 2)
        XCTAssertEqual(selection.members[1].name, registeredName1)
    }

    // MARK: - selectForDisplay: Overflow

    func testSelectForDisplay_NoOverflowWith3OrFewer() {
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: profileName2, role: MemberRoles.member),
            makeCandidate(name: profileName3, role: MemberRoles.member)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members.count, 3)
        XCTAssertEqual(selection.overflowCount, 0)
    }

    func testSelectForDisplay_OverflowWith4Members() {
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: profileName2, role: MemberRoles.member),
            makeCandidate(name: profileName3, role: MemberRoles.member),
            makeCandidate(name: profileName4, role: MemberRoles.member)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members.count, 2)
        XCTAssertEqual(selection.overflowCount, 2)
    }

    func testSelectForDisplay_OverflowExcludesInactiveFromCount() {
        let candidates = [
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: profileName2, role: MemberRoles.member),
            makeCandidate(name: profileName3, role: MemberRoles.member),
            makeCandidate(name: profileName4, role: MemberRoles.banned),
            makeCandidate(name: registeredName1, role: MemberRoles.left)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.members.count, 3)
        XCTAssertEqual(selection.overflowCount, 0)
    }

    // MARK: - selectForDisplay: selectedIndices

    func testSelectForDisplay_IndicesMapToOriginalArray() {
        let candidates = [
            makeCandidate(name: profileName3, role: MemberRoles.banned),
            makeCandidate(name: profileName1, role: MemberRoles.admin),
            makeCandidate(name: profileName4, role: MemberRoles.left),
            makeCandidate(name: profileName2, role: MemberRoles.member)
        ]
        let selection = GroupAvatarRenderer.selectForDisplay(from: candidates)
        XCTAssertEqual(selection.selectedIndices.count, 2)
        XCTAssertTrue(selection.selectedIndices.contains(1))
        XCTAssertTrue(selection.selectedIndices.contains(3))
        XCTAssertEqual(candidates[selection.selectedIndices[0]].role, MemberRoles.admin)
    }

    // MARK: - GroupAvatarMember Equality

    func testMemberEquality_SameImageInstance() {
        let image = createTestImage()
        let m1 = GroupAvatarMember(image: image, name: profileName1)
        let m2 = GroupAvatarMember(image: image, name: profileName1)
        XCTAssertEqual(m1, m2)
    }

    func testMemberEquality_DifferentImageInstances() {
        let m1 = GroupAvatarMember(image: createTestImage(), name: profileName1)
        let m2 = GroupAvatarMember(image: createTestImage(), name: profileName1)
        XCTAssertNotEqual(m1, m2)
    }

    func testMemberEquality_BothNilImages() {
        let m1 = GroupAvatarMember(image: nil, name: profileName1)
        let m2 = GroupAvatarMember(image: nil, name: profileName1)
        XCTAssertEqual(m1, m2)
    }

    func testMemberEquality_DifferentNames() {
        let image = createTestImage()
        let m1 = GroupAvatarMember(image: image, name: profileName1)
        let m2 = GroupAvatarMember(image: image, name: profileName2)
        XCTAssertNotEqual(m1, m2)
    }

    // MARK: - MemberRoles

    func testMemberRoles_ActiveContainsExpectedRoles() {
        XCTAssertTrue(MemberRoles.active.contains(MemberRoles.admin))
        XCTAssertTrue(MemberRoles.active.contains(MemberRoles.member))
        XCTAssertTrue(MemberRoles.active.contains(MemberRoles.invited))
        XCTAssertFalse(MemberRoles.active.contains(MemberRoles.banned))
        XCTAssertFalse(MemberRoles.active.contains(MemberRoles.left))
        XCTAssertEqual(MemberRoles.active.count, 3)
    }

    // MARK: - GroupAvatarMember.resolve

    func testResolve_PrefersProfileName() {
        let member = GroupAvatarMember.resolve(
            profilePhoto: nil, profileName: profileName1,
            registeredName: registeredName1, jamiId: jamiId1
        )
        XCTAssertEqual(member.name, profileName1)
        XCTAssertNil(member.image)
    }

    func testResolve_FallsBackToRegisteredName() {
        let member = GroupAvatarMember.resolve(
            profilePhoto: nil, profileName: nil,
            registeredName: registeredName1, jamiId: jamiId1
        )
        XCTAssertEqual(member.name, registeredName1)
    }

    func testResolve_FallsBackToJamiId() {
        let member = GroupAvatarMember.resolve(
            profilePhoto: nil, profileName: nil,
            registeredName: nil, jamiId: jamiId1
        )
        XCTAssertEqual(member.name, jamiId1)
    }

    func testResolve_DecodesBase64Photo() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let pngData = renderer.pngData { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let base64 = pngData.base64EncodedString()
        let member = GroupAvatarMember.resolve(
            profilePhoto: base64, profileName: profileName1,
            registeredName: nil, jamiId: jamiId1
        )
        XCTAssertNotNil(member.image)
        XCTAssertEqual(member.name, profileName1)
    }
}
