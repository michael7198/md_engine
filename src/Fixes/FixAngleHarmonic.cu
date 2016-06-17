
#include "FixHelpers.h"
#include "helpers.h"
#include "FixAngleHarmonic.h"
#include "cutils_func.h"
#include "AngleEvaluate.h"
using namespace std;
const string angleHarmonicType = "AngleHarmonic";
FixAngleHarmonic::FixAngleHarmonic(boost::shared_ptr<State> state_, string handle)
  : FixPotentialMultiAtom(state_, handle, angleHarmonicType, true)
{
  if (state->readConfig->fileOpen) {
    auto restData = state->readConfig->readFix(type, handle);
    if (restData) {
      std::cout << "Reading restart data for fix " << handle << std::endl;
      readFromRestart(restData);
    }
  }
}

namespace py = boost::python;

void FixAngleHarmonic::compute(bool computeVirials) {
    int nAtoms = state->atoms.size();
    int activeIdx = state->gpd.activeIdx();
    compute_force_angle<<<NBLOCK(nAtoms), PERBLOCK, sizeof(AngleGPU) * maxForcersPerBlock + parameters.size() * sizeof(AngleHarmonicType)>>>(nAtoms, state->gpd.xs(activeIdx), state->gpd.fs(activeIdx), state->gpd.idToIdxs.getTex(), forcersGPU.data(), forcerIdxs.data(), state->boundsGPU, parameters.data(), parameters.size(), evaluator);

}

void FixAngleHarmonic::singlePointEng(float *perParticleEng) {
    int nAtoms = state->atoms.size();
    int activeIdx = state->gpd.activeIdx();
    compute_energy_angle<<<NBLOCK(nAtoms), PERBLOCK, sizeof(AngleGPU) * maxForcersPerBlock + parameters.size() * sizeof(AngleHarmonicType)>>>(nAtoms, state->gpd.xs(activeIdx), perParticleEng, state->gpd.idToIdxs.getTex(), forcersGPU.data(), forcerIdxs.data(), state->boundsGPU, parameters.data(), parameters.size(), evaluator);
}
//void cumulativeSum(int *data, int n);
// okay, so the net result of this function is that two arrays (items, idxs of
// items) are on the gpu and we know how many bonds are in bondiest block

void FixAngleHarmonic::createAngle(Atom *a, Atom *b, Atom *c, double k, double thetaEq, int type) {
    vector<Atom *> atoms = {a, b, c};
    validAtoms(atoms);
    if (type == -1) {
        assert(k!=COEF_DEFAULT and thetaEq!=COEF_DEFAULT);
    }
    forcers.push_back(AngleHarmonic(a, b, c, k, thetaEq, type));
    pyListInterface.updateAppendedMember();
}

void FixAngleHarmonic::setAngleTypeCoefs(int type, double k, double thetaEq) {
    //cout << type << " " << k << " " << thetaEq << endl;
    assert(thetaEq>=0);
    AngleHarmonic dummy(k, thetaEq);
    setForcerType(type, dummy);
}


bool FixAngleHarmonic::readFromRestart(pugi::xml_node restData) {
  auto curr_node = restData.first_child();
  while (curr_node) {
    std::string tag = curr_node.name();
    if (tag == "types") {
      for (auto type_node = curr_node.first_child(); type_node; type_node = type_node.next_sibling()) {
        int type;
        double k;
        double thetaEq;
	std::string type_ = type_node.attribute("id").value();
        type = atoi(type_.c_str());
	std::string k_ = type_node.attribute("k").value();
	std::string thetaEq_ = type_node.attribute("thetaEq").value();
        k = atof(k_.c_str());
        thetaEq = atof(thetaEq_.c_str());

        setAngleTypeCoefs(type, k, thetaEq);
      }
    } else if (tag == "members") {
      for (auto member_node = curr_node.first_child(); member_node; member_node = member_node.next_sibling()) {
        int type;
        double k;
        double thetaEq;
        int ids[3];
	std::string type_ = member_node.attribute("type").value();
	std::string atom_a = member_node.attribute("atom_a").value();
	std::string atom_b = member_node.attribute("atom_b").value();
	std::string atom_c = member_node.attribute("atom_c").value();
	std::string k_ = member_node.attribute("k").value();
	std::string thetaEq_ = member_node.attribute("thetaEq").value();
        type = atoi(type_.c_str());
        ids[0] = atoi(atom_a.c_str());
        ids[1] = atoi(atom_b.c_str());
        ids[2] = atoi(atom_c.c_str());
        Atom aa = state->idToAtom(ids[0]);
        Atom bb = state->idToAtom(ids[1]);
        Atom cc = state->idToAtom(ids[2]);
        Atom * a = &aa;
	Atom * b = &bb;
	Atom * c = &cc;
	k = atof(k_.c_str());
        thetaEq = atof(thetaEq_.c_str());

        createAngle(a, b, c, k, thetaEq, type);
      }
    }
    curr_node = curr_node.next_sibling();
  }
  return true;
}

void export_FixAngleHarmonic() {
    boost::python::class_<FixAngleHarmonic,
                          boost::shared_ptr<FixAngleHarmonic>,
                          boost::python::bases<Fix, TypedItemHolder> >(
        "FixAngleHarmonic",
        boost::python::init<boost::shared_ptr<State>, string>(
                                boost::python::args("state", "handle"))
    )
    .def("createAngle", &FixAngleHarmonic::createAngle,
            (boost::python::arg("k")=COEF_DEFAULT,
             boost::python::arg("thetaEq")=COEF_DEFAULT,
             boost::python::arg("type")=-1)
        )
    .def("setAngleTypeCoefs", &FixAngleHarmonic::setAngleTypeCoefs,
            (boost::python::arg("type")=-1,
             boost::python::arg("k")=COEF_DEFAULT,
             boost::python::arg("thetaEq")=COEF_DEFAULT
            )
        )
    .def_readonly("angles", &FixAngleHarmonic::pyForcers)
    ;
}

