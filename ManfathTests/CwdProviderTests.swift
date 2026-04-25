import XCTest
@testable import ManfathCore

final class CwdProviderTests: XCTestCase {

    // MARK: - package.json

    func testParsePackageJsonName() {
        let json = #"""
        {
          "name": "my-awesome-app",
          "version": "1.2.3",
          "scripts": { "dev": "vite" }
        }
        """#
        let name = CwdProvider.parsePackageJsonName(Data(json.utf8))
        XCTAssertEqual(name, "my-awesome-app")
    }

    func testParsePackageJsonMissingName() {
        let json = #"{"version": "1.0.0"}"#
        XCTAssertNil(CwdProvider.parsePackageJsonName(Data(json.utf8)))
    }

    func testParsePackageJsonEmptyName() {
        let json = #"{"name": ""}"#
        XCTAssertNil(CwdProvider.parsePackageJsonName(Data(json.utf8)))
    }

    func testParsePackageJsonInvalidJson() {
        XCTAssertNil(CwdProvider.parsePackageJsonName(Data("not json".utf8)))
    }

    // MARK: - Cargo.toml / pyproject.toml

    func testParseCargoTomlName() {
        let toml = """
        [package]
        name = "my-rust-crate"
        version = "0.1.0"
        edition = "2021"
        """
        XCTAssertEqual(CwdProvider.parseTomlName(from: toml), "my-rust-crate")
    }

    func testParsePyprojectTomlName() {
        let toml = """
        [project]
        name = "ml-pipeline"
        version = "0.2.0"
        requires-python = ">=3.10"
        """
        XCTAssertEqual(CwdProvider.parseTomlName(from: toml), "ml-pipeline")
    }

    func testParsePyprojectPoetryStyle() {
        let toml = """
        [tool.poetry]
        name = "poetry-app"
        version = "0.1.0"
        """
        XCTAssertEqual(CwdProvider.parseTomlName(from: toml), "poetry-app")
    }

    func testParseTomlWithSingleQuotes() {
        let toml = """
        [package]
        name = 'single-quoted'
        """
        XCTAssertEqual(CwdProvider.parseTomlName(from: toml), "single-quoted")
    }

    func testParseTomlWithoutSpaces() {
        let toml = #"name="tight""#
        XCTAssertEqual(CwdProvider.parseTomlName(from: toml), "tight")
    }

    func testParseTomlNoName() {
        let toml = """
        [package]
        version = "0.1.0"
        """
        XCTAssertNil(CwdProvider.parseTomlName(from: toml))
    }

    // MARK: - go.mod

    func testParseGoModExtractsLastPathComponent() {
        let modFile = """
        module github.com/acme/cool-service

        go 1.21

        require (
            github.com/stretchr/testify v1.8.4
        )
        """
        XCTAssertEqual(CwdProvider.parseGoModName(from: modFile), "cool-service")
    }

    func testParseGoModSimpleModuleName() {
        XCTAssertEqual(CwdProvider.parseGoModName(from: "module myapp"), "myapp")
    }

    func testParseGoModMissing() {
        XCTAssertNil(CwdProvider.parseGoModName(from: "go 1.21"))
    }

    // MARK: - readProjectName integration (temp dir)

    func testReadProjectNamePrefersPackageJsonOverFolderName() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("manfath-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let pkg = tmp.appendingPathComponent("package.json")
        try #"{"name": "from-package-json"}"#.write(to: pkg, atomically: true, encoding: .utf8)

        let result = CwdProvider.readProjectName(at: tmp.path)
        XCTAssertEqual(result, "from-package-json")
    }

    func testReadProjectNameReturnsNilForEmptyDir() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("manfath-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // No manifests and no .git → readProjectName declines.
        // The folder-name fallback now lives in resolveProjectName.
        XCTAssertNil(CwdProvider.readProjectName(at: tmp.path))
    }

    func testReadProjectNameRecognizesGitDir() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("manfath-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent(".git"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = CwdProvider.readProjectName(at: tmp.path)
        XCTAssertEqual(result, tmp.lastPathComponent)
    }

    // MARK: - Parent-dir walk

    func testWalkFindsManifestInParent() {
        let fs = MockFileSystem(files: [
            "/Users/me/code/proj/package.json": #"{"name": "proj-pkg"}"#,
            // /Users/me/code/proj/src/server has no manifest
        ])
        let name = CwdProvider.walkForProjectName(
            startingAt: "/Users/me/code/proj/src/server",
            fileSystem: fs
        )
        XCTAssertEqual(name, "proj-pkg")
    }

    func testWalkStopsAtRoot() {
        let fs = MockFileSystem(files: [:])
        XCTAssertNil(
            CwdProvider.walkForProjectName(startingAt: "/Users/me/code/proj", fileSystem: fs)
        )
    }

    func testWalkRespectsMaxDepth() {
        let fs = MockFileSystem(files: [
            "/a/package.json": #"{"name": "shallow"}"#,
        ])
        // /a/b/c/d/e/f/g is 6 levels below /a, exceeds default maxDepth=5
        XCTAssertNil(CwdProvider.walkForProjectName(
            startingAt: "/a/b/c/d/e/f/g",
            fileSystem: fs
        ))
        // 5 levels is within bounds
        XCTAssertEqual(CwdProvider.walkForProjectName(
            startingAt: "/a/b/c/d/e/f",
            fileSystem: fs
        ), "shallow")
    }

    // MARK: - .app helper detection

    func testAppBundleNameExtractsBareName() {
        XCTAssertEqual(
            CwdProvider.appBundleName(from: "/Applications/Adobe XD.app/Contents/MacOS/Adobe XD"),
            "Adobe XD"
        )
        XCTAssertEqual(
            CwdProvider.appBundleName(from: "/Applications/Slack.app/Contents/MacOS/Slack Helper"),
            "Slack"
        )
    }

    func testAppBundleNameIgnoresNonAppPaths() {
        XCTAssertNil(CwdProvider.appBundleName(from: "/usr/bin/node"))
        XCTAssertNil(CwdProvider.appBundleName(from: "/Users/me/proj/server.js"))
    }

    // MARK: - looksLikePath

    func testLooksLikePathRejectsFlagsAndBare() {
        XCTAssertFalse(CwdProvider.looksLikePath(""))
        XCTAssertFalse(CwdProvider.looksLikePath("--port=3000"))
        XCTAssertFalse(CwdProvider.looksLikePath("dev"))
        XCTAssertTrue(CwdProvider.looksLikePath("/Users/me/proj/server.js"))
        XCTAssertTrue(CwdProvider.looksLikePath("./bin/start"))
    }

    // MARK: - resolveProjectName end-to-end

    func testResolveUsesCwdManifestFirst() {
        let fs = MockFileSystem(files: [
            "/Users/me/proj/package.json": #"{"name": "from-cwd"}"#,
            "/Users/me/elsewhere/package.json": #"{"name": "decoy"}"#,
        ])
        let name = CwdProvider.resolveProjectName(
            workingDirectory: "/Users/me/proj",
            executablePath: nil,
            arguments: [],
            fileSystem: fs
        )
        XCTAssertEqual(name, "from-cwd")
    }

    func testResolveFallsBackToArgsWhenCwdHasNothing() {
        let fs = MockFileSystem(files: [
            "/Users/me/work/myapp/package.json": #"{"name": "myapp-from-args"}"#,
        ])
        let name = CwdProvider.resolveProjectName(
            workingDirectory: "/", // no project here
            executablePath: "/usr/bin/node",
            arguments: ["node", "/Users/me/work/myapp/dist/server.js"],
            fileSystem: fs
        )
        XCTAssertEqual(name, "myapp-from-args")
    }

    func testResolveDetectsAppHelperWhenNoProject() {
        let fs = MockFileSystem(files: [:])
        let name = CwdProvider.resolveProjectName(
            workingDirectory: nil,
            executablePath: "/Applications/Adobe Creative Cloud.app/Contents/MacOS/Crash Reporter",
            arguments: [],
            fileSystem: fs
        )
        XCTAssertEqual(name, "Adobe Creative Cloud")
    }

    func testResolveLastResortFolderName() {
        let fs = MockFileSystem(files: [:])
        let name = CwdProvider.resolveProjectName(
            workingDirectory: "/Users/me/random-folder",
            executablePath: nil,
            arguments: [],
            fileSystem: fs
        )
        XCTAssertEqual(name, "random-folder")
    }

    func testResolveAppHelperBeatsLastResortFolder() {
        // App helpers should be identified before falling back to a
        // generic folder name, otherwise users see "MacOS" or similar.
        let fs = MockFileSystem(files: [:])
        let name = CwdProvider.resolveProjectName(
            workingDirectory: "/Applications/Notion.app/Contents/MacOS",
            executablePath: "/Applications/Notion.app/Contents/MacOS/Notion",
            arguments: [],
            fileSystem: fs
        )
        XCTAssertEqual(name, "Notion")
    }
}

// MARK: - In-memory FileSystem for path-walk tests

private struct MockFileSystem: FileSystemReader {
    let files: [String: String]

    func exists(path: String) -> Bool { files[path] != nil }
    func read(path: String) -> Data? { files[path].map { Data($0.utf8) } }
    func readString(path: String) -> String? { files[path] }
}
