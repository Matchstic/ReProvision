#ifndef LDID_HPP
#define LDID_HPP

#include <cstdlib>
#include <map>
#include <set>
#include <sstream>
#include <streambuf>
#include <string>
#include <vector>

namespace ldid {

// I wish Apple cared about providing quality toolchains :/

template <typename Function_>
class Functor;

template <typename Type_, typename... Args_>
class Functor<Type_ (Args_...)> {
  public:
    virtual Type_ operator ()(Args_... args) const = 0;
};

template <typename Function_>
class FunctorImpl;

template <typename Value_, typename Type_, typename... Args_>
class FunctorImpl<Type_ (Value_::*)(Args_...) const> :
    public Functor<Type_ (Args_...)>
{
  private:
    const Value_ *value_;

  public:
    FunctorImpl(const Value_ &value) :
        value_(&value)
    {
    }

    virtual Type_ operator ()(Args_... args) const {
        return (*value_)(args...);
    }
};

template <typename Function_>
FunctorImpl<decltype(&Function_::operator())> fun(const Function_ &value) {
    return value;
}

class Folder {
  public:
    virtual void Save(const std::string &path, const void *flag, const Functor<void (std::streambuf &)> &code) = 0;
    virtual bool Look(const std::string &path) = 0;
    virtual void Open(const std::string &path, const Functor<void (std::streambuf &, const void *)> &code) = 0;
    virtual void Find(const std::string &path, const Functor<void (const std::string &, const Functor<void (const Functor<void (std::streambuf &, std::streambuf &)> &)> &)> &code, const Functor<void (const std::string &, const Functor<std::string ()> &)> &link) = 0;
};

class DiskFolder :
    public Folder
{
  private:
    const std::string path_;
    std::map<std::string, std::string> commit_;

    std::string Path(const std::string &path);

    void Find(const std::string &root, const std::string &base, const Functor<void (const std::string &, const Functor<void (const Functor<void (std::streambuf &, std::streambuf &)> &)> &)> &code, const Functor<void (const std::string &, const Functor<std::string ()> &)> &link);

  public:
    DiskFolder(const std::string &path);
    ~DiskFolder();

    virtual void Save(const std::string &path, const void *flag, const Functor<void (std::streambuf &)> &code);
    virtual bool Look(const std::string &path);
    virtual void Open(const std::string &path, const Functor<void (std::streambuf &, const void *)> &code);
    virtual void Find(const std::string &path, const Functor<void (const std::string &, const Functor<void (const Functor<void (std::streambuf &, std::streambuf &)> &)> &)> &code, const Functor<void (const std::string &, const Functor<std::string ()> &)> &link);
};

class SubFolder :
    public Folder
{
  private:
    Folder &parent_;
    std::string path_;

  public:
    SubFolder(Folder &parent, const std::string &path);

    virtual void Save(const std::string &path, const void *flag, const Functor<void (std::streambuf &)> &code);
    virtual bool Look(const std::string &path);
    virtual void Open(const std::string &path, const Functor<void (std::streambuf &, const void *)> &code);
    virtual void Find(const std::string &path, const Functor<void (const std::string &, const Functor<void (const Functor<void (std::streambuf &, std::streambuf &)> &)> &)> &code, const Functor<void (const std::string &, const Functor<std::string ()> &)> &link);
};

class UnionFolder :
    public Folder
{
  private:
    class StringBuffer :
        public std::stringbuf
    {
      public:
        StringBuffer() {
        }

        StringBuffer(const StringBuffer &rhs) :
            std::stringbuf(rhs.str())
        {
        }
    };

    Folder &parent_;
    std::set<std::string> deletes_;

    std::map<std::string, std::string> remaps_;
    std::map<std::string, std::pair<StringBuffer, const void *>> resets_;

    std::string Map(const std::string &path);
    void Map(const std::string &path, const Functor<void (const std::string &, const Functor<void (const Functor<void (std::streambuf &, std::streambuf &)> &)> &)> &code, const std::string &file, const Functor<void (const Functor<void (std::streambuf &, const void *)> &)> &save);

  public:
    UnionFolder(Folder &parent);

    virtual void Save(const std::string &path, const void *flag, const Functor<void (std::streambuf &)> &code);
    virtual bool Look(const std::string &path);
    virtual void Open(const std::string &path, const Functor<void (std::streambuf &, const void *)> &code);
    virtual void Find(const std::string &path, const Functor<void (const std::string &, const Functor<void (const Functor<void (std::streambuf &, std::streambuf &)> &)> &)> &code, const Functor<void (const std::string &, const Functor<std::string ()> &)> &link);

    void operator ()(const std::string &from) {
        deletes_.insert(from);
    }

    void operator ()(const std::string &from, const std::string &to) {
        operator ()(from);
        remaps_[to] = from;
    }

    std::stringbuf &operator ()(const std::string &from, const void *flag) {
        operator ()(from);
        auto &reset(resets_[from]);
        reset.second = flag;
        return reset.first;
    }
};

struct Bundle {
    std::string path;
    std::vector<char> hash;
};

Bundle Sign(const std::string &root, Folder &folder, const std::string &key, const std::string &entitlements, const std::string &requirement);

typedef std::map<uint32_t, std::vector<char>> Slots;

std::string Analyze(const void *data, size_t size);
std::vector<char> Sign(const void *idata, size_t isize, std::streambuf &output, const std::string &identifier, const std::string &entitlements, const std::string &requirement, const std::string &key, const Slots &slots);

}

#endif//LDID_HPP
