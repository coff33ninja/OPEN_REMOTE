package system

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func (e *Executor) CreateDirectory(parent string, name string) (FileEntry, error) {
	if parent == "" {
		return FileEntry{}, fmt.Errorf("parent_path is required")
	}

	safeName, err := validateEntryName(name)
	if err != nil {
		return FileEntry{}, err
	}

	targetPath := filepath.Join(parent, safeName)
	if err := os.Mkdir(targetPath, 0o755); err != nil {
		return FileEntry{}, err
	}

	return fileEntryForPath(targetPath)
}

func (e *Executor) RenameEntry(target string, newName string) (FileEntry, error) {
	if strings.TrimSpace(target) == "" {
		return FileEntry{}, fmt.Errorf("path is required")
	}

	safeName, err := validateEntryName(newName)
	if err != nil {
		return FileEntry{}, err
	}

	sourcePath := filepath.Clean(target)
	destinationPath := filepath.Join(filepath.Dir(sourcePath), safeName)
	if sourcePath == destinationPath {
		return fileEntryForPath(sourcePath)
	}

	if _, err := os.Stat(destinationPath); err == nil {
		return FileEntry{}, fmt.Errorf("destination already exists")
	} else if !os.IsNotExist(err) {
		return FileEntry{}, err
	}

	if err := os.Rename(sourcePath, destinationPath); err != nil {
		return FileEntry{}, err
	}

	return fileEntryForPath(destinationPath)
}

func (e *Executor) DeleteEntry(target string) error {
	if strings.TrimSpace(target) == "" {
		return fmt.Errorf("path is required")
	}

	return os.RemoveAll(filepath.Clean(target))
}

func (e *Executor) MoveEntry(source string, destination string) (FileEntry, error) {
	if strings.TrimSpace(source) == "" || strings.TrimSpace(destination) == "" {
		return FileEntry{}, fmt.Errorf("source_path and destination_path are required")
	}

	sourcePath := filepath.Clean(source)
	destinationPath := filepath.Clean(destination)
	if sourcePath == destinationPath {
		return fileEntryForPath(destinationPath)
	}

	if _, err := os.Stat(destinationPath); err == nil {
		return FileEntry{}, fmt.Errorf("destination already exists")
	} else if !os.IsNotExist(err) {
		return FileEntry{}, err
	}

	if err := os.MkdirAll(filepath.Dir(destinationPath), 0o755); err != nil {
		return FileEntry{}, err
	}

	if err := os.Rename(sourcePath, destinationPath); err != nil {
		return FileEntry{}, err
	}

	return fileEntryForPath(destinationPath)
}

func (e *Executor) CopyEntry(source string, destination string) (FileEntry, error) {
	if strings.TrimSpace(source) == "" || strings.TrimSpace(destination) == "" {
		return FileEntry{}, fmt.Errorf("source_path and destination_path are required")
	}

	sourcePath := filepath.Clean(source)
	destinationPath := filepath.Clean(destination)
	if sourcePath == destinationPath {
		return FileEntry{}, fmt.Errorf("destination must differ from source")
	}

	info, err := os.Stat(sourcePath)
	if err != nil {
		return FileEntry{}, err
	}

	if _, err := os.Stat(destinationPath); err == nil {
		return FileEntry{}, fmt.Errorf("destination already exists")
	} else if !os.IsNotExist(err) {
		return FileEntry{}, err
	}

	if err := copyPath(sourcePath, destinationPath, info); err != nil {
		return FileEntry{}, err
	}

	return fileEntryForPath(destinationPath)
}

func (e *Executor) ReadFile(target string) ([]byte, FileEntry, error) {
	if strings.TrimSpace(target) == "" {
		return nil, FileEntry{}, fmt.Errorf("path is required")
	}

	cleanTarget := filepath.Clean(target)
	info, err := os.Stat(cleanTarget)
	if err != nil {
		return nil, FileEntry{}, err
	}
	if info.IsDir() {
		return nil, FileEntry{}, fmt.Errorf("path is a directory")
	}

	blob, err := os.ReadFile(cleanTarget)
	if err != nil {
		return nil, FileEntry{}, err
	}

	entry, err := fileEntryForInfo(cleanTarget, info)
	if err != nil {
		return nil, FileEntry{}, err
	}

	return blob, entry, nil
}

func fileEntryForPath(target string) (FileEntry, error) {
	info, err := os.Stat(target)
	if err != nil {
		return FileEntry{}, err
	}

	return fileEntryForInfo(target, info)
}

func fileEntryForInfo(target string, info fs.FileInfo) (FileEntry, error) {
	if info == nil {
		return FileEntry{}, fmt.Errorf("file info is required")
	}

	return FileEntry{
		Name:     filepath.Base(target),
		Path:     target,
		IsDir:    info.IsDir(),
		Size:     info.Size(),
		Modified: info.ModTime().UTC().Format(time.RFC3339),
	}, nil
}

func validateEntryName(name string) (string, error) {
	candidate := strings.TrimSpace(name)
	if candidate == "" {
		return "", fmt.Errorf("name is required")
	}
	if candidate == "." || candidate == ".." {
		return "", fmt.Errorf("invalid name")
	}
	if strings.ContainsAny(candidate, `/\`) {
		return "", fmt.Errorf("name cannot contain path separators")
	}
	return candidate, nil
}

func copyPath(source string, destination string, info fs.FileInfo) error {
	if info.IsDir() {
		return copyDirectory(source, destination, info)
	}
	return copyFile(source, destination, info)
}

func copyDirectory(source string, destination string, info fs.FileInfo) error {
	if err := os.MkdirAll(destination, info.Mode().Perm()); err != nil {
		return err
	}

	entries, err := os.ReadDir(source)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		childSource := filepath.Join(source, entry.Name())
		childInfo, err := entry.Info()
		if err != nil {
			return err
		}
		childDestination := filepath.Join(destination, entry.Name())
		if err := copyPath(childSource, childDestination, childInfo); err != nil {
			return err
		}
	}

	return nil
}

func copyFile(source string, destination string, info fs.FileInfo) error {
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}

	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()

	output, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, info.Mode().Perm())
	if err != nil {
		return err
	}
	defer output.Close()

	if _, err := io.Copy(output, input); err != nil {
		return err
	}

	return output.Close()
}
