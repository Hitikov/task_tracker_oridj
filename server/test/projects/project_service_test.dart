import 'package:arij_server/src/models/user.dart';
import 'package:arij_server/src/repositories/project_repository.dart';
import 'package:arij_server/src/services/project_service.dart';
import 'package:test/test.dart';

import '../auth/fake_user_repository.dart';
import 'fake_project_repository.dart';

void main() {
  const unknownProjectId = '00000000-0000-4000-8000-000000000000';

  late FakeUserRepository userRepository;
  late FakeProjectRepository repository;
  late ProjectService service;

  setUp(() {
    userRepository = FakeUserRepository();
    repository = FakeProjectRepository(userRepository);
    service = ProjectService(repository: repository);
  });

  Future<User> addUser({required String email, String name = 'User'}) async {
    final record = await userRepository.create(
      email: email,
      name: name,
      passwordHash: 'hash',
    );
    return record.user;
  }

  group('createProject', () {
    test('creates project and records the owner member', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'ARIJ',
        name: 'Arij MVP',
        description: 'Трекер задач',
      );
      expect(project.id, isNotEmpty);
      expect(project.key, 'ARIJ');
      expect(project.name, 'Arij MVP');
      expect(project.description, 'Трекер задач');
      expect(project.ownerId, owner.id);
      expect(project.createdAt, isA<DateTime>());
      expect(project.updatedAt, isA<DateTime>());

      final members = await service.listMembers(
        userId: owner.id,
        projectId: project.id,
      );
      expect(members, hasLength(1));
      expect(members.single.userId, owner.id);
      expect(members.single.role, 'owner');
    });

    test('uppercases the key (OpenAPI create pattern)', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'demo1',
        name: 'Demo',
      );
      expect(project.key, 'DEMO1');
    });

    test('trims name and description', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'X1',
        name: '  Arij  ',
        description: '  d  ',
      );
      expect(project.name, 'Arij');
      expect(project.description, 'd');
    });

    test('rejects invalid keys with 400 field=key', () async {
      final owner = await addUser(email: 'ada@example.com');
      for (final key in <String>['a', 'a b', 'A!B', 'aBCDEXYZABCD', '']) {
        await expectLater(
          service.createProject(userId: owner.id, key: key, name: 'N'),
          throwsA(
            isA<ValidationException>().having((e) => e.field, 'field', 'key'),
          ),
        );
      }
    });

    test('rejects long names (>100)', () async {
      final owner = await addUser(email: 'ada@example.com');
      await expectLater(
        service.createProject(userId: owner.id, key: 'K1', name: 'A' * 101),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects long descriptions (>2000)', () async {
      final owner = await addUser(email: 'ada@example.com');
      await expectLater(
        service.createProject(
          userId: owner.id,
          key: 'K1',
          name: 'N',
          description: 'D' * 2001,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('duplicate key → ProjectKeyTakenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      await service.createProject(userId: owner.id, key: 'DUP1', name: 'One');
      await expectLater(
        service.createProject(userId: owner.id, key: 'DUP1', name: 'Two'),
        throwsA(isA<ProjectKeyTakenException>()),
      );
    });

    test('duplicate key ignoring case → ProjectKeyTakenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      await service.createProject(userId: owner.id, key: 'DUP1', name: 'One');
      await expectLater(
        service.createProject(userId: owner.id, key: 'dup1', name: 'Two'),
        throwsA(isA<ProjectKeyTakenException>()),
      );
    });
  });

  group('getProject', () {
    test('owner sees the project', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'G1',
        name: 'G',
      );
      expect(
        (await service.getProject(userId: owner.id, projectId: project.id)).id,
        project.id,
      );
    });

    test('member sees the project', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'G2',
        name: 'G',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      expect(
        (await service.getProject(userId: member.id, projectId: project.id)).id,
        project.id,
      );
    });

    test('non-member → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final outsider = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'G3',
        name: 'G',
      );
      await expectLater(
        service.getProject(userId: outsider.id, projectId: project.id),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown id → NotFoundException project_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      await expectLater(
        service.getProject(userId: owner.id, projectId: unknownProjectId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'project_not_found',
          ),
        ),
      );
    });
  });

  group('updateProject', () {
    test('owner updates the name', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'U1',
        name: 'Old',
      );
      final updated = await service.updateProject(
        userId: owner.id,
        projectId: project.id,
        fields: <String, Object?>{'name': 'New'},
      );
      expect(updated.name, 'New');
      expect(updated.key, 'U1');
    });

    test('owner clears the description with null', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'U2',
        name: 'N',
        description: 'd',
      );
      final updated = await service.updateProject(
        userId: owner.id,
        projectId: project.id,
        fields: const <String, Object?>{'description': null},
      );
      expect(updated.description, isNull);
    });

    test('member → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'U3',
        name: 'N',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      await expectLater(
        service.updateProject(
          userId: member.id,
          projectId: project.id,
          fields: const <String, Object?>{'name': 'X'},
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('non-member → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final outsider = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'U4',
        name: 'N',
      );
      await expectLater(
        service.updateProject(
          userId: outsider.id,
          projectId: project.id,
          fields: const <String, Object?>{'name': 'X'},
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown id → NotFoundException', () async {
      final owner = await addUser(email: 'ada@example.com');
      await expectLater(
        service.updateProject(
          userId: owner.id,
          projectId: unknownProjectId,
          fields: const <String, Object?>{'name': 'X'},
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('empty fields → 400 validation_error', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'U5',
        name: 'N',
      );
      await expectLater(
        service.updateProject(
          userId: owner.id,
          projectId: project.id,
          fields: const <String, Object?>{},
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('attempt to pass the immutable key → 400', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'U6',
        name: 'N',
      );
      await expectLater(
        service.updateProject(
          userId: owner.id,
          projectId: project.id,
          fields: const <String, Object?>{'key': 'NEW'},
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'key'),
        ),
      );
    });

    test('invalid name → 400 validation_error field=name', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'U7',
        name: 'N',
      );
      await expectLater(
        service.updateProject(
          userId: owner.id,
          projectId: project.id,
          fields: <String, Object?>{'name': ''},
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'name'),
        ),
      );
    });
  });

  group('deleteProject', () {
    test('owner deletes the project', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'D1',
        name: 'N',
      );
      await service.deleteProject(userId: owner.id, projectId: project.id);
      expect(await repository.findById(project.id), isNull);
    });

    test('member → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'D2',
        name: 'N',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      await expectLater(
        service.deleteProject(userId: member.id, projectId: project.id),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('non-member → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final outsider = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'D3',
        name: 'N',
      );
      await expectLater(
        service.deleteProject(userId: outsider.id, projectId: project.id),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown id → NotFoundException', () async {
      final owner = await addUser(email: 'ada@example.com');
      await expectLater(
        service.deleteProject(userId: owner.id, projectId: unknownProjectId),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('listProjects', () {
    test('returns owner and member projects, not others', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final outsider = await addUser(email: 'carol@example.com');
      final p1 = await service.createProject(
        userId: owner.id,
        key: 'L1',
        name: 'One',
      );
      final p2 = await service.createProject(
        userId: member.id,
        key: 'L2',
        name: 'Two',
      );
      await service.addMember(
        userId: owner.id,
        projectId: p1.id,
        email: member.email,
      );
      expect(
        (await service.listProjects(member.id)).map((p) => p.id),
        containsAll(<String>[p1.id, p2.id]),
      );
      expect(await service.listProjects(outsider.id), isEmpty);
    });
  });

  group('listMembers', () {
    test('owner and member see members with roles', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'M1',
        name: 'N',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      expect(
        (await service.listMembers(
          userId: owner.id,
          projectId: project.id,
        )).map((m) => m.role).toSet(),
        <String>{'owner', 'member'},
      );
      expect(
        (await service.listMembers(
          userId: member.id,
          projectId: project.id,
        )).map((m) => m.role).toSet(),
        <String>{'owner', 'member'},
      );
    });

    test('non-member → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final outsider = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'M2',
        name: 'N',
      );
      await expectLater(
        service.listMembers(userId: outsider.id, projectId: project.id),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown id → NotFoundException', () async {
      final owner = await addUser(email: 'ada@example.com');
      await expectLater(
        service.listMembers(userId: owner.id, projectId: unknownProjectId),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('addMember', () {
    test('owner adds an existing user → role=member', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(
        name: 'Иван Петров',
        email: 'boris@example.com',
      );
      final project = await service.createProject(
        userId: owner.id,
        key: 'AM1',
        name: 'N',
      );
      final added = await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      expect(added.role, 'member');
      expect(added.userId, member.id);
      expect(added.email, member.email);
      expect(added.name, 'Иван Петров');
    });

    test('owner attempts role=owner → 400 validation_error', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'AM2',
        name: 'N',
      );
      await expectLater(
        service.addMember(
          userId: owner.id,
          projectId: project.id,
          email: 'second@example.com',
          role: 'owner',
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'role'),
        ),
      );
    });

    test('unknown email → NotFoundException user_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'AM3',
        name: 'N',
      );
      await expectLater(
        service.addMember(
          userId: owner.id,
          projectId: project.id,
          email: 'ghost@example.com',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('member already in the project → MemberExistsException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'AM4',
        name: 'N',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      await expectLater(
        service.addMember(
          userId: owner.id,
          projectId: project.id,
          email: member.email,
        ),
        throwsA(isA<MemberExistsException>()),
      );
    });

    test('member caller → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'AM5',
        name: 'N',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      await expectLater(
        service.addMember(
          userId: member.id,
          projectId: project.id,
          email: 'carol@example.com',
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown project → NotFoundException', () async {
      final owner = await addUser(email: 'ada@example.com');
      await expectLater(
        service.addMember(
          userId: owner.id,
          projectId: unknownProjectId,
          email: 'x@example.com',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('removeMember', () {
    test('owner removes a member → listMembers excludes them', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'RM1',
        name: 'N',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      await service.removeMember(
        userId: owner.id,
        projectId: project.id,
        userIdToRemove: member.id,
      );
      final members = await service.listMembers(
        userId: owner.id,
        projectId: project.id,
      );
      expect(members.map((m) => m.userId), isNot(contains(member.id)));
    });

    test('owner cannot remove the owner → OwnerRemovalException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'RM2',
        name: 'N',
      );
      await expectLater(
        service.removeMember(
          userId: owner.id,
          projectId: project.id,
          userIdToRemove: owner.id,
        ),
        throwsA(isA<OwnerRemovalException>()),
      );
    });

    test('target not a member → NotFoundException member_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final stranger = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'RM3',
        name: 'N',
      );
      await expectLater(
        service.removeMember(
          userId: owner.id,
          projectId: project.id,
          userIdToRemove: stranger.id,
        ),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'member_not_found',
          ),
        ),
      );
    });

    test('member caller → ForbiddenException', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await service.createProject(
        userId: owner.id,
        key: 'RM4',
        name: 'N',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      await expectLater(
        service.removeMember(
          userId: member.id,
          projectId: project.id,
          userIdToRemove: owner.id,
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });
}
